from decimal import Decimal

from django.db import models
from django.utils import timezone

from apps.accounts.models import ParentProfile


class Wallet(models.Model):
    parent = models.OneToOneField(
        ParentProfile, on_delete=models.CASCADE, related_name="wallet"
    )
    balance = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    currency = models.CharField(max_length=8, default="KZT")
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "wallets"

    def __str__(self) -> str:
        return f"Wallet {self.parent} = {self.balance} {self.currency}"


class WalletTransaction(models.Model):
    class Kind(models.TextChoices):
        TOPUP = "topup", "Пополнение"
        TRIP_CHARGE = "trip_charge", "Оплата поездки"
        REFUND = "refund", "Возврат"
        SUBSCRIPTION = "subscription", "Покупка абонемента"

    wallet = models.ForeignKey(
        Wallet, on_delete=models.CASCADE, related_name="transactions"
    )
    kind = models.CharField(max_length=16, choices=Kind.choices)
    # Positive = credit, negative = debit.
    amount = models.DecimalField(max_digits=12, decimal_places=2)
    balance_after = models.DecimalField(max_digits=12, decimal_places=2)
    trip = models.ForeignKey(
        "trips.Trip", on_delete=models.SET_NULL, null=True, blank=True
    )
    note = models.CharField(max_length=255, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "wallet_transactions"
        ordering = ["-created_at"]


class TopUpIntent(models.Model):
    """A wallet top-up going through the (mock) bank checkout flow:
    create → bank page → callback → wallet credited. Mirrors a real PSP."""

    class Status(models.TextChoices):
        PENDING = "pending", "В обработке"
        SUCCESS = "success", "Успешно"
        FAILED = "failed", "Ошибка"

    parent = models.ForeignKey(
        ParentProfile, on_delete=models.CASCADE, related_name="topups"
    )
    amount = models.DecimalField(max_digits=12, decimal_places=2)
    ref = models.CharField(max_length=64, unique=True)
    provider = models.CharField(max_length=20, default="mock")
    status = models.CharField(
        max_length=12, choices=Status.choices, default=Status.PENDING
    )
    raw_payload = models.JSONField(default=dict, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "topup_intents"
        ordering = ["-created_at"]


class SubscriptionPlan(models.Model):
    """Месячный абонемент: N поездок за фиксированную цену."""

    name = models.CharField(max_length=80)
    trips_count = models.PositiveIntegerField()
    price = models.DecimalField(max_digits=10, decimal_places=2)
    duration_days = models.PositiveIntegerField(default=30)
    is_active = models.BooleanField(default=True)

    class Meta:
        db_table = "subscription_plans"

    def __str__(self) -> str:
        return f"{self.name} ({self.trips_count} поездок / {self.price})"

    @property
    def price_per_trip(self) -> Decimal:
        if not self.trips_count:
            return Decimal("0")
        return (self.price / self.trips_count).quantize(Decimal("1"))


class Subscription(models.Model):
    class Status(models.TextChoices):
        ACTIVE = "active", "Активен"
        EXPIRED = "expired", "Истёк"
        CANCELLED = "cancelled", "Отменён"

    parent = models.ForeignKey(
        ParentProfile, on_delete=models.CASCADE, related_name="subscriptions"
    )
    plan = models.ForeignKey(SubscriptionPlan, on_delete=models.PROTECT)
    trips_total = models.PositiveIntegerField()
    trips_used = models.PositiveIntegerField(default=0)
    valid_until = models.DateField()
    status = models.CharField(
        max_length=12, choices=Status.choices, default=Status.ACTIVE
    )
    auto_renew = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "subscriptions"
        ordering = ["-created_at"]

    @property
    def trips_remaining(self) -> int:
        return max(self.trips_total - self.trips_used, 0)

    @property
    def is_usable(self) -> bool:
        return (
            self.status == self.Status.ACTIVE
            and self.trips_remaining > 0
            and self.valid_until >= timezone.localdate()
        )
