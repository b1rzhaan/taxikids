from django.db import models

from apps.accounts.models import User


class SalaryScheme(models.Model):
    """How a driver's earning per trip is calculated."""

    class Type(models.TextChoices):
        PERCENT = "percent", "Percent of trip price"
        FIXED = "fixed_per_trip", "Fixed amount per trip"

    name = models.CharField(max_length=80)
    type = models.CharField(max_length=20, choices=Type.choices, default=Type.PERCENT)
    # percent → 0..1 (0.70); fixed → amount in currency units
    value = models.DecimalField(max_digits=10, decimal_places=2)
    is_active = models.BooleanField(default=True)

    class Meta:
        db_table = "salary_schemes"

    def __str__(self) -> str:
        return f"{self.name} ({self.type})"

    def earning_for(self, trip_price):
        from decimal import Decimal

        if self.type == self.Type.PERCENT:
            return (Decimal(trip_price) * self.value).quantize(Decimal("0.01"))
        return self.value


class DriverProfile(models.Model):
    class DocStatus(models.TextChoices):
        PENDING = "pending", "Pending review"
        APPROVED = "approved", "Approved"
        REJECTED = "rejected", "Rejected"

    user = models.OneToOneField(
        User, on_delete=models.CASCADE, related_name="driver_profile"
    )
    full_name = models.CharField(max_length=120)
    phone = models.CharField(max_length=32, blank=True)
    # Driver's portrait, driving licence and ID-card photos (cabinet review).
    photo = models.FileField(upload_to="drivers/photos/", null=True, blank=True)
    license_photo = models.FileField(
        upload_to="drivers/licenses/", null=True, blank=True
    )
    id_card_photo = models.FileField(
        upload_to="drivers/id_cards/", null=True, blank=True
    )
    iin = models.CharField("ИИН", max_length=12, blank=True)
    license_number = models.CharField(max_length=40, blank=True)
    license_expiry = models.DateField(null=True, blank=True)
    doc_status = models.CharField(
        max_length=12, choices=DocStatus.choices, default=DocStatus.PENDING
    )
    experience_years = models.PositiveSmallIntegerField(default=0)
    has_child_seat = models.BooleanField(default=True)
    rating = models.DecimalField(max_digits=3, decimal_places=2, default=5.00)
    is_available = models.BooleanField(default=True)
    salary_scheme = models.ForeignKey(
        SalaryScheme, on_delete=models.SET_NULL, null=True, blank=True
    )
    hired_at = models.DateField(null=True, blank=True)
    # Last known live position (updated by the driver app / demo simulator).
    last_lat = models.FloatField(null=True, blank=True)
    last_lng = models.FloatField(null=True, blank=True)
    last_heading = models.FloatField(default=0)
    last_seen_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        db_table = "driver_profiles"
        ordering = ["full_name"]

    def __str__(self) -> str:
        return self.full_name


class Vehicle(models.Model):
    driver = models.ForeignKey(
        DriverProfile,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="vehicles",
    )
    make = models.CharField(max_length=40)
    model = models.CharField(max_length=40)
    plate_number = models.CharField(max_length=16, unique=True)
    color = models.CharField(max_length=30, blank=True)
    seats = models.PositiveSmallIntegerField(default=4)
    year = models.PositiveSmallIntegerField(null=True, blank=True)
    mileage_km = models.PositiveIntegerField(null=True, blank=True)
    photo = models.FileField(upload_to="vehicles/", null=True, blank=True)
    tech_passport = models.CharField(max_length=40, blank=True)
    is_active = models.BooleanField(default=True)

    class Meta:
        db_table = "vehicles"

    def __str__(self) -> str:
        return f"{self.make} {self.model} {self.plate_number}"


class Tariff(models.Model):
    """Pricing rule used to estimate a trip's price."""

    name = models.CharField(max_length=80)
    base_fare = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    per_km = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    per_min = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    min_fare = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    is_active = models.BooleanField(default=True)

    class Meta:
        db_table = "tariffs"

    def __str__(self) -> str:
        return self.name

    def price_for(self, distance_m: int, duration_s: int):
        from decimal import Decimal

        km = Decimal(distance_m) / Decimal(1000)
        minutes = Decimal(duration_s) / Decimal(60)
        price = self.base_fare + self.per_km * km + self.per_min * minutes
        price = max(price, self.min_fare)
        return price.quantize(Decimal("1"))
