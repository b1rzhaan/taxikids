import csv
import datetime as dt

from django.http import HttpResponse
from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework import mixins, viewsets
from rest_framework.decorators import action, api_view, permission_classes
from rest_framework.response import Response

from apps.accounts.models import Role
from apps.accounts.permissions import IsDriver, IsFinanceRole
from apps.drivers.models import DriverProfile

from .models import DriverEarning, Payout
from .serializers import (
    CreatePayoutSerializer,
    DriverEarningSerializer,
    PayoutSerializer,
)
from .services import create_payout, mark_paid


@api_view(["POST"])
@permission_classes([IsDriver])
def request_payout(request):
    """Driver requests a payout for their accrued earnings (last 30 days)."""
    d = request.user.driver_profile
    today = timezone.localdate()
    payout = create_payout(d, today - dt.timedelta(days=30), today, request.user)
    return Response(PayoutSerializer(payout).data, status=201)


class EarningViewSet(mixins.ListModelMixin, viewsets.GenericViewSet):
    serializer_class = DriverEarningSerializer
    filterset_fields = ["status", "driver"]

    def get_queryset(self):
        user = self.request.user
        qs = DriverEarning.objects.select_related("driver", "trip")
        if user.role == Role.DRIVER:
            return qs.filter(driver__user=user)
        return qs  # accountant / admin


class PayoutViewSet(viewsets.ModelViewSet):
    serializer_class = PayoutSerializer
    filterset_fields = ["status", "driver"]

    def get_permissions(self):
        return [IsFinanceRole()]

    def get_queryset(self):
        return Payout.objects.select_related("driver").all()

    def create(self, request, *args, **kwargs):
        ser = CreatePayoutSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        driver = get_object_or_404(DriverProfile, pk=ser.validated_data["driver_id"])
        payout = create_payout(
            driver,
            ser.validated_data["period_start"],
            ser.validated_data["period_end"],
            request.user,
        )
        return Response(PayoutSerializer(payout).data, status=201)

    @action(detail=True, methods=["post"])
    def mark_paid(self, request, pk=None):
        payout = self.get_object()
        payout = mark_paid(payout)
        return Response(PayoutSerializer(payout).data)

    @action(detail=True, methods=["get"])
    def export(self, request, pk=None):
        payout = self.get_object()
        resp = HttpResponse(content_type="text/csv")
        resp["Content-Disposition"] = f'attachment; filename="payout_{payout.id}.csv"'
        writer = csv.writer(resp)
        writer.writerow(["trip_id", "date", "amount"])
        for item in payout.items.select_related("earning__trip"):
            e = item.earning
            writer.writerow([e.trip_id, e.created_at.date(), e.amount])
        writer.writerow(["TOTAL", "", payout.total_amount])
        return resp
