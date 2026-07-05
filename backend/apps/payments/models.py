from django.db import models

from apps.accounts.models import ParentProfile
from apps.trips.models import Trip


class Payment(models.Model):
    class Status(models.TextChoices):
        PENDING = "pending", "В обработке"
        SUCCESS = "success", "Успешно"
        FAILED = "failed", "Ошибка"
        REFUNDED = "refunded", "Возврат"

    trip = models.ForeignKey(
        Trip, on_delete=models.CASCADE, related_name="payments"
    )
    parent = models.ForeignKey(ParentProfile, on_delete=models.PROTECT)
    provider = models.CharField(max_length=20, default="mock")
    provider_ref = models.CharField(max_length=120, blank=True, db_index=True)
    amount = models.DecimalField(max_digits=10, decimal_places=2)
    currency = models.CharField(max_length=8, default="KZT")
    status = models.CharField(
        max_length=12, choices=Status.choices, default=Status.PENDING
    )
    idempotency_key = models.CharField(max_length=64, unique=True)
    raw_payload = models.JSONField(default=dict, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    paid_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        db_table = "payments"
        ordering = ["-created_at"]

    def __str__(self) -> str:
        return f"Payment #{self.pk} trip={self.trip_id} {self.status}"
