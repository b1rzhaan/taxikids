from django.db import models

from apps.accounts.models import User
from apps.drivers.models import DriverProfile


class DriverEarning(models.Model):
    """Amount accrued to a driver for one completed trip (snapshot)."""

    class Status(models.TextChoices):
        ACCRUED = "accrued", "Начислено"
        INCLUDED = "included_in_payout", "В выплате"
        CANCELLED = "cancelled", "Отменено"

    driver = models.ForeignKey(
        DriverProfile, on_delete=models.CASCADE, related_name="earnings"
    )
    trip = models.OneToOneField(
        "trips.Trip", on_delete=models.CASCADE, related_name="earning"
    )
    amount = models.DecimalField(max_digits=10, decimal_places=2)
    status = models.CharField(
        max_length=20, choices=Status.choices, default=Status.ACCRUED
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "driver_earnings"
        ordering = ["-created_at"]


class Payout(models.Model):
    class Status(models.TextChoices):
        PENDING = "pending", "Ожидает"
        PAID = "paid", "Выплачено"
        CANCELLED = "cancelled", "Отменено"

    driver = models.ForeignKey(
        DriverProfile, on_delete=models.PROTECT, related_name="payouts"
    )
    period_start = models.DateField()
    period_end = models.DateField()
    total_amount = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    status = models.CharField(
        max_length=12, choices=Status.choices, default=Status.PENDING
    )
    created_by = models.ForeignKey(
        User, on_delete=models.SET_NULL, null=True, related_name="created_payouts"
    )
    paid_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "payouts"
        ordering = ["-created_at"]


class PayoutItem(models.Model):
    payout = models.ForeignKey(
        Payout, on_delete=models.CASCADE, related_name="items"
    )
    earning = models.OneToOneField(DriverEarning, on_delete=models.PROTECT)

    class Meta:
        db_table = "payout_items"
