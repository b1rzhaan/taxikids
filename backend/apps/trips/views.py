from django.shortcuts import get_object_or_404
from rest_framework import status, viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import PermissionDenied, ValidationError
from rest_framework.response import Response

from apps.accounts.models import Role
from apps.accounts.permissions import IsAdminOrOperator, IsDriver

from .models import RecurringTripPlan, Trip, TripLocation, TripStatus
from .serializers import (
    DriverLocationSerializer,
    RecurringTripPlanSerializer,
    TripAssignSerializer,
    TripCreateSerializer,
    TripDetailSerializer,
    TripListSerializer,
    TripStatusEventSerializer,
)
from .services import TripService, TripTransitionError
from .ws import broadcast_location


class TripViewSet(viewsets.ModelViewSet):
    filterset_fields = ["status", "payment_status"]
    ordering_fields = ["scheduled_at", "created_at"]

    def get_queryset(self):
        user = self.request.user
        qs = Trip.objects.select_related(
            "child", "driver", "parent", "tariff"
        ).prefetch_related("children", "ratings")
        if user.role == Role.PARENT:
            return qs.filter(parent__user=user)
        if user.role == Role.DRIVER:
            return qs.filter(driver__user=user)
        return qs  # operator / admin / accountant → all

    def get_serializer_class(self):
        if self.action == "create":
            return TripCreateSerializer
        if self.action == "list":
            return TripListSerializer
        return TripDetailSerializer

    def create(self, request, *args, **kwargs):
        if request.user.role != Role.PARENT:
            raise PermissionDenied("Только родитель создаёт заказ через приложение.")
        ser = self.get_serializer(data=request.data)
        ser.is_valid(raise_exception=True)
        trip = ser.save()
        # Return the full detail (with computed route + price) to the client.
        from rest_framework import status as http_status
        return Response(
            TripDetailSerializer(trip).data, status=http_status.HTTP_201_CREATED
        )

    # ── Steate machine endpoint ───────────────────────────────────────
    @action(detail=True, methods=["post"])
    def status(self, request, pk=None):
        """POST /api/trips/{id}/status/ {event, note}."""
        trip = self.get_object()
        ser = TripStatusEventSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        try:
            trip = TripService.transition(
                trip, ser.validated_data["event"], request.user,
                note=ser.validated_data.get("note", ""),
            )
        except TripTransitionError as exc:
            raise ValidationError({"detail": str(exc)})
        return Response(TripDetailSerializer(trip).data)

    @action(detail=False, methods=["get"], permission_classes=[IsDriver])
    def available(self, request):
        """Paid orders not yet taken by any driver — the driver's job board."""
        qs = Trip.objects.filter(
            status=TripStatus.PAID, driver__isnull=True
        ).select_related("child", "parent").prefetch_related("children").order_by("scheduled_at")
        return Response(TripListSerializer(qs, many=True).data)

    @action(detail=True, methods=["post"], permission_classes=[IsDriver])
    def accept(self, request, pk=None):
        """Driver takes a paid, unassigned order (bypasses get_queryset filter)."""
        trip = get_object_or_404(Trip, pk=pk)
        try:
            trip = TripService.accept(trip, request.user)
        except TripTransitionError as exc:
            raise ValidationError({"detail": str(exc)})
        return Response(TripDetailSerializer(trip).data)

    @action(detail=True, methods=["post"], permission_classes=[IsAdminOrOperator])
    def assign(self, request, pk=None):
        """POST /api/trips/{id}/assign/ {driver_id, vehicle_id?}."""
        trip = self.get_object()
        ser = TripAssignSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        try:
            trip = TripService.transition(
                trip, "assign", request.user, **ser.validated_data
            )
        except TripTransitionError as exc:
            raise ValidationError({"detail": str(exc)})
        return Response(TripDetailSerializer(trip).data)

    @action(detail=True, methods=["post"])
    def pay_cash(self, request, pk=None):
        """Parent (or staff) chooses cash: the order becomes assignable now and
        the fare is collected by the driver at the end of the ride."""
        trip = self.get_object()
        if request.user.role == Role.PARENT and trip.parent.user_id != request.user.id:
            raise PermissionDenied("Not your trip")
        try:
            trip = TripService.transition(trip, "confirm_cash", request.user)
        except TripTransitionError as exc:
            raise ValidationError({"detail": str(exc)})
        return Response(TripDetailSerializer(trip).data)

    @action(detail=True, methods=["post"])
    def cancel(self, request, pk=None):
        trip = self.get_object()
        try:
            trip = TripService.transition(
                trip, "cancel", request.user,
                note=request.data.get("note", ""),
            )
        except TripTransitionError as exc:
            raise ValidationError({"detail": str(exc)})
        return Response(TripDetailSerializer(trip).data)

    @action(detail=True, methods=["post"])
    def rate(self, request, pk=None):
        """Parent rates the driver / driver rates the trip after completion."""
        from django.db.models import Avg

        from .models import TripRating

        trip = self.get_object()
        role = request.user.role
        if role not in (Role.PARENT, Role.DRIVER):
            raise PermissionDenied("Оценивать могут только родитель и водитель.")
        if trip.status != TripStatus.COMPLETED:
            raise ValidationError({"detail": "Оценить можно только завершённую поездку"})
        try:
            stars = int(request.data.get("stars"))
        except (TypeError, ValueError):
            raise ValidationError({"detail": "stars 1..5 обязательны"})
        if not 1 <= stars <= 5:
            raise ValidationError({"detail": "stars должно быть 1..5"})

        TripRating.objects.update_or_create(
            trip=trip,
            role=role,
            defaults={
                "rated_by": request.user,
                "stars": stars,
                "comment": str(request.data.get("comment", ""))[:255],
            },
        )
        # A parent's rating updates the driver's aggregate rating.
        if role == Role.PARENT and trip.driver_id:
            avg = TripRating.objects.filter(
                role=Role.PARENT, trip__driver_id=trip.driver_id
            ).aggregate(a=Avg("stars"))["a"]
            if avg:
                trip.driver.rating = round(avg, 2)
                trip.driver.save(update_fields=["rating"])
        return Response({"status": "ok", "stars": stars})

    @action(detail=True, methods=["get"])
    def history(self, request, pk=None):
        from .serializers import TripStatusHistorySerializer

        trip = self.get_object()
        return Response(
            TripStatusHistorySerializer(trip.status_history.all(), many=True).data
        )

    # ── Live tracking ────────────────────────────────────────────────
    @action(detail=True, methods=["post"])
    def location(self, request, pk=None):
        """Driver pushes GPS: POST /api/trips/{id}/location/ {lat,lng,...}."""
        trip = self.get_object()
        if request.user.role != Role.DRIVER or trip.driver_id != getattr(
            getattr(request.user, "driver_profile", None), "id", None
        ):
            raise PermissionDenied("Только назначенный водитель.")
        ser = DriverLocationSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        loc = TripLocation.objects.create(
            trip=trip, driver=trip.driver, **ser.validated_data
        )
        # Also update the driver's live position so the cabinet map shows them.
        from apps.drivers.views import update_driver_position

        update_driver_position(
            trip.driver,
            ser.validated_data["lat"],
            ser.validated_data["lng"],
        )
        broadcast_location(trip.id, ser.validated_data)
        return Response(
            {"recorded_at": loc.recorded_at}, status=status.HTTP_201_CREATED
        )

    @action(detail=True, methods=["get"])
    def track(self, request, pk=None):
        """Latest known driver position for the trip."""
        trip = self.get_object()
        loc = trip.locations.first()
        if not loc:
            return Response({"detail": "no location yet"}, status=404)
        return Response(DriverLocationSerializer(loc).data)


class RecurringTripPlanViewSet(viewsets.ModelViewSet):
    serializer_class = RecurringTripPlanSerializer

    def get_queryset(self):
        user = self.request.user
        if user.role == Role.PARENT:
            return RecurringTripPlan.objects.filter(parent__user=user)
        return RecurringTripPlan.objects.all()
