import datetime as dt
import math

from django.db.models import Sum
from django.utils import timezone
from rest_framework import viewsets
from rest_framework.decorators import action, api_view, parser_classes, permission_classes
from rest_framework.parsers import FormParser, JSONParser, MultiPartParser
from rest_framework.response import Response

from apps.accounts.permissions import (
    IsAdmin,
    IsAdminOrOperator,
    IsDriver,
    IsStaffRole,
)

from .models import DriverProfile, SalaryScheme, Tariff, Vehicle
from .serializers import (
    DriverProfileSerializer,
    SalarySchemeSerializer,
    TariffSerializer,
    VehicleSerializer,
)


def _driver_me_payload(request, d):
    from apps.payouts.models import DriverEarning
    from apps.trips.models import Trip, TripRating, TripStatus

    today = timezone.localdate()
    week = today - dt.timedelta(days=7)
    month = today - dt.timedelta(days=30)
    earn = DriverEarning.objects.filter(driver=d)

    def total(qs):
        return qs.aggregate(x=Sum("amount"))["x"] or 0

    vehicle = d.vehicles.filter(is_active=True).first()
    return {
        "id": d.id,
        "full_name": d.full_name,
        "phone": d.phone,
        "photo": request.build_absolute_uri(d.photo.url) if d.photo else "",
        "iin": d.iin,
        "doc_status": d.doc_status,
        "rating": str(d.rating),
        "reviews_count": TripRating.objects.filter(
            role="parent", trip__driver=d).count(),
        "is_available": d.is_available,
        "experience_years": d.experience_years,
        "has_child_seat": d.has_child_seat,
        "vehicle": VehicleSerializer(vehicle).data if vehicle else None,
        "stats": {
            "earned_today": total(earn.filter(created_at__date=today)),
            "earned_week": total(earn.filter(created_at__date__gte=week)),
            "earned_month": total(earn.filter(created_at__date__gte=month)),
            "balance": total(earn.filter(status=DriverEarning.Status.ACCRUED)),
            "trips_today": Trip.objects.filter(
                driver=d, status=TripStatus.COMPLETED,
                updated_at__date=today).count(),
            "completed_total": Trip.objects.filter(
                driver=d, status=TripStatus.COMPLETED).count(),
        },
    }


@api_view(["GET", "PATCH"])
@permission_classes([IsDriver])
@parser_classes([MultiPartParser, FormParser])
def driver_me(request):
    """The driver's own profile + dashboard stats."""
    d = request.user.driver_profile
    if request.method == "PATCH":
        photo = request.FILES.get("photo")
        if photo:
            d.photo = photo
            d.save(update_fields=["photo"])
    return Response(_driver_me_payload(request, d))


@api_view(["POST"])
@permission_classes([IsDriver])
@parser_classes([MultiPartParser, FormParser])
def driver_me_photo(request):
    """Upload/replace the current driver's profile photo."""
    d = request.user.driver_profile
    photo = request.FILES.get("photo")
    if not photo:
        return Response({"detail": "photo is required"}, status=400)
    d.photo = photo
    d.save(update_fields=["photo"])
    return Response(_driver_me_payload(request, d))


def update_driver_position(driver, lat, lng):
    """Store a driver's REAL GPS position (pushed from the driver app) and
    derive a heading from the previous point so the map icon points forward."""
    if driver.last_lat is not None and driver.last_lng is not None:
        dy = lat - driver.last_lat
        dx = lng - driver.last_lng
        if abs(dx) > 1e-7 or abs(dy) > 1e-7:
            driver.last_heading = (math.degrees(math.atan2(dx, dy))) % 360
    driver.last_lat = lat
    driver.last_lng = lng
    driver.last_seen_at = timezone.now()
    driver.save(
        update_fields=["last_lat", "last_lng", "last_heading", "last_seen_at"]
    )


@api_view(["GET"])
@permission_classes([IsStaffRole])
def drivers_locations(request):
    """Live positions of taxis on the line — REAL coordinates pushed by the
    driver apps in the last few minutes (no simulation)."""
    cutoff = timezone.now() - dt.timedelta(minutes=3)
    result = []
    qs = (
        DriverProfile.objects.filter(
            is_available=True,
            last_lat__isnull=False,
            last_seen_at__gte=cutoff,
        )
        .prefetch_related("vehicles")
    )
    for d in qs:
        vehicle = next((v for v in d.vehicles.all() if v.is_active), None)
        result.append({
            "id": d.id,
            "full_name": d.full_name,
            "rating": str(d.rating),
            "phone": d.phone,
            "photo": request.build_absolute_uri(d.photo.url) if d.photo else None,
            "lat": d.last_lat,
            "lng": d.last_lng,
            "heading": d.last_heading,
            "vehicle": (
                {
                    "make": vehicle.make,
                    "model": vehicle.model,
                    "plate_number": vehicle.plate_number,
                    "color": vehicle.color,
                }
                if vehicle
                else None
            ),
        })
    return Response(result)


@api_view(["POST"])
@permission_classes([IsDriver])
def driver_set_online(request):
    d = request.user.driver_profile
    d.is_available = bool(request.data.get("is_available", not d.is_available))
    d.save(update_fields=["is_available"])
    return Response({"is_available": d.is_available})


class DriverViewSet(viewsets.ModelViewSet):
    queryset = DriverProfile.objects.select_related("user", "salary_scheme").all()
    serializer_class = DriverProfileSerializer
    parser_classes = [MultiPartParser, FormParser, JSONParser]
    filterset_fields = ["doc_status", "is_available"]
    search_fields = ["full_name", "phone", "iin"]

    def get_permissions(self):
        # Operators view drivers and review applications; only admin edits records.
        if self.action in ("list", "retrieve", "stats"):
            return [IsStaffRole()]
        if self.action in ("approve_docs", "reject_docs"):
            return [IsAdminOrOperator()]
        return [IsAdmin()]

    @action(detail=True, methods=["get"], permission_classes=[IsStaffRole])
    def stats(self, request, pk=None):
        """Profile figures for the cabinet: earnings, payouts, weekly income."""
        from apps.payouts.models import DriverEarning, Payout
        from apps.trips.models import Trip, TripRating, TripStatus

        d = self.get_object()
        today = timezone.localdate()
        earn = DriverEarning.objects.filter(driver=d)

        def total(qs):
            return qs.aggregate(x=Sum("amount"))["x"] or 0

        income_by_day = []
        for i in range(6, -1, -1):
            day = today - dt.timedelta(days=i)
            income_by_day.append({
                "day": day.isoformat(),
                "amount": float(total(earn.filter(created_at__date=day))),
            })

        payouts = [
            {
                "id": p.id,
                "period_start": p.period_start,
                "period_end": p.period_end,
                "total_amount": p.total_amount,
                "status": p.status,
                "paid_at": p.paid_at,
            }
            for p in Payout.objects.filter(driver=d)[:8]
        ]

        return Response({
            "earned_today": total(earn.filter(created_at__date=today)),
            "earned_week": total(
                earn.filter(created_at__date__gte=today - dt.timedelta(days=7))
            ),
            "trips_today": Trip.objects.filter(
                driver=d, status=TripStatus.COMPLETED, updated_at__date=today
            ).count(),
            "completed_total": Trip.objects.filter(
                driver=d, status=TripStatus.COMPLETED
            ).count(),
            "pending_amount": total(
                earn.filter(status=DriverEarning.Status.ACCRUED)
            ),
            "reviews_count": TripRating.objects.filter(
                role="parent", trip__driver=d
            ).count(),
            "income_by_day": income_by_day,
            "payouts": payouts,
        })

    @action(detail=True, methods=["post"], permission_classes=[IsAdminOrOperator])
    def approve_docs(self, request, pk=None):
        driver = self.get_object()
        driver.doc_status = DriverProfile.DocStatus.APPROVED
        driver.save(update_fields=["doc_status"])
        return Response({"status": driver.doc_status})

    @action(detail=True, methods=["post"], permission_classes=[IsAdminOrOperator])
    def reject_docs(self, request, pk=None):
        driver = self.get_object()
        driver.doc_status = DriverProfile.DocStatus.REJECTED
        driver.save(update_fields=["doc_status"])
        return Response({"status": driver.doc_status})


class VehicleViewSet(viewsets.ModelViewSet):
    queryset = Vehicle.objects.select_related("driver").all()
    serializer_class = VehicleSerializer
    permission_classes = [IsAdminOrOperator]
    parser_classes = [MultiPartParser, FormParser, JSONParser]
    filterset_fields = ["is_active", "driver"]


class TariffViewSet(viewsets.ModelViewSet):
    queryset = Tariff.objects.all()
    serializer_class = TariffSerializer

    def get_permissions(self):
        if self.action in ("list", "retrieve"):
            return [IsStaffRole()]
        return [IsAdmin()]


class SalarySchemeViewSet(viewsets.ModelViewSet):
    queryset = SalaryScheme.objects.all()
    serializer_class = SalarySchemeSerializer
    permission_classes = [IsAdmin]
