from django.conf import settings
from django.db import models

from apps.accounts.models import ParentProfile, User
from apps.children.models import Child
from apps.drivers.models import DriverProfile, Tariff, Vehicle


class TripStatus(models.TextChoices):
    CREATED = "created", "Создан"
    WAITING_PAYMENT = "waiting_payment", "Ожидает оплаты"
    PAID = "paid", "Оплачен"
    DRIVER_ASSIGNED = "driver_assigned", "Водитель назначен"
    DRIVER_ON_WAY = "driver_on_way", "Водитель выехал"
    DRIVER_ARRIVED = "driver_arrived", "Водитель прибыл"
    CHILD_PICKED_UP = "child_picked_up", "Ребёнок забран"
    IN_PROGRESS = "in_progress", "В пути"
    CHILD_DELIVERED = "child_delivered", "Ребёнок доставлен"
    COMPLETED = "completed", "Завершён"
    CANCELLED = "cancelled", "Отменён"


class PaymentStatus(models.TextChoices):
    UNPAID = "unpaid", "Не оплачен"
    PENDING = "pending", "В обработке"
    PAID = "paid", "Оплачен"
    REFUNDED = "refunded", "Возврат"
    FAILED = "failed", "Ошибка"


class PaymentMethod(models.TextChoices):
    CARD = "card", "Картой"
    CASH = "cash", "Наличными"


class Weekday(models.IntegerChoices):
    MON = 0, "Пн"
    TUE = 1, "Вт"
    WED = 2, "Ср"
    THU = 3, "Чт"
    FRI = 4, "Пт"
    SAT = 5, "Сб"
    SUN = 6, "Вс"


class RecurringTripPlan(models.Model):
    """Template that generates concrete Trips on a weekly schedule."""

    parent = models.ForeignKey(
        ParentProfile, on_delete=models.CASCADE, related_name="trip_plans"
    )
    child = models.ForeignKey(Child, on_delete=models.CASCADE)

    pickup_text = models.CharField(max_length=255)
    pickup_lat = models.FloatField()
    pickup_lng = models.FloatField()
    dropoff_text = models.CharField(max_length=255)
    dropoff_lat = models.FloatField()
    dropoff_lng = models.FloatField()

    weekdays = models.JSONField(default=list)  # e.g. [0,1,2,3,4]
    pickup_time = models.TimeField()
    tariff = models.ForeignKey(Tariff, on_delete=models.SET_NULL, null=True)

    is_active = models.BooleanField(default=True)
    valid_from = models.DateField()
    valid_to = models.DateField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "recurring_trip_plans"

    def __str__(self) -> str:
        return f"Plan #{self.pk} {self.child} {self.weekdays}@{self.pickup_time}"


class Trip(models.Model):
    plan = models.ForeignKey(
        RecurringTripPlan,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="trips",
    )
    parent = models.ForeignKey(
        ParentProfile, on_delete=models.PROTECT, related_name="trips"
    )
    child = models.ForeignKey(Child, on_delete=models.PROTECT)
    children = models.ManyToManyField(Child, blank=True, related_name="shared_trips")
    driver = models.ForeignKey(
        DriverProfile,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="trips",
    )
    vehicle = models.ForeignKey(
        Vehicle, on_delete=models.SET_NULL, null=True, blank=True
    )

    pickup_text = models.CharField(max_length=255)
    pickup_lat = models.FloatField()
    pickup_lng = models.FloatField()
    dropoff_text = models.CharField(max_length=255)
    dropoff_lat = models.FloatField()
    dropoff_lng = models.FloatField()

    scheduled_at = models.DateTimeField()
    route_distance_m = models.PositiveIntegerField(default=0)
    route_duration_s = models.PositiveIntegerField(default=0)
    route_polyline = models.JSONField(default=list, blank=True)

    tariff = models.ForeignKey(Tariff, on_delete=models.SET_NULL, null=True)
    price_amount = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    price_currency = models.CharField(max_length=8, default="KZT")

    status = models.CharField(
        max_length=20, choices=TripStatus.choices, default=TripStatus.CREATED
    )
    payment_status = models.CharField(
        max_length=12, choices=PaymentStatus.choices, default=PaymentStatus.UNPAID
    )
    payment_method = models.CharField(
        max_length=8, choices=PaymentMethod.choices, default=PaymentMethod.CARD
    )
    # Snapshot of the driver's earning, frozen when the trip completes.
    driver_earning_amount = models.DecimalField(
        max_digits=10, decimal_places=2, default=0
    )

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "trips"
        ordering = ["-scheduled_at"]
        indexes = [
            models.Index(fields=["status"]),
            models.Index(fields=["driver", "status"]),
        ]

    def __str__(self) -> str:
        return f"Trip #{self.pk} {self.child} [{self.status}]"


class TripStatusHistory(models.Model):
    trip = models.ForeignKey(
        Trip, on_delete=models.CASCADE, related_name="status_history"
    )
    from_status = models.CharField(max_length=20, blank=True)
    to_status = models.CharField(max_length=20)
    event = models.CharField(max_length=40, blank=True)
    actor = models.ForeignKey(
        User, on_delete=models.SET_NULL, null=True, blank=True
    )
    note = models.CharField(max_length=255, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "trip_status_history"
        ordering = ["created_at"]


class TripRating(models.Model):
    """A rating left after a completed trip — one per side (parent / driver)."""

    trip = models.ForeignKey(Trip, on_delete=models.CASCADE, related_name="ratings")
    rated_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True)
    role = models.CharField(max_length=10)  # parent | driver
    stars = models.PositiveSmallIntegerField()
    comment = models.CharField(max_length=255, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "trip_ratings"
        unique_together = ("trip", "role")


class TripLocation(models.Model):
    """Append-only driver location stream during a trip (live tracking)."""

    trip = models.ForeignKey(
        Trip, on_delete=models.CASCADE, related_name="locations"
    )
    driver = models.ForeignKey(DriverProfile, on_delete=models.CASCADE)
    lat = models.FloatField()
    lng = models.FloatField()
    speed = models.FloatField(null=True, blank=True)
    heading = models.FloatField(null=True, blank=True)
    recorded_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "trip_locations"
        ordering = ["-recorded_at"]
        indexes = [models.Index(fields=["trip", "-recorded_at"])]
