from django.contrib.auth.models import AbstractBaseUser, PermissionsMixin
from django.db import models
from django.utils import timezone

from .managers import UserManager


class Role(models.TextChoices):
    PARENT = "parent", "Parent / Client"
    DRIVER = "driver", "Driver"
    OPERATOR = "operator", "Operator"
    ADMIN = "admin", "Admin"
    ACCOUNTANT = "accountant", "Accountant"


# Roles that belong to internal staff and use the web cabinet.
STAFF_ROLES = {Role.OPERATOR, Role.ADMIN, Role.ACCOUNTANT}


class User(AbstractBaseUser, PermissionsMixin):
    """Custom user: login by email, single role per account."""

    email = models.EmailField(unique=True)
    phone = models.CharField(max_length=32, blank=True)
    role = models.CharField(max_length=20, choices=Role.choices, default=Role.PARENT)

    is_active = models.BooleanField(default=True)
    is_staff = models.BooleanField(default=False)  # Django admin access

    date_joined = models.DateTimeField(default=timezone.now)

    objects = UserManager()

    USERNAME_FIELD = "email"
    REQUIRED_FIELDS = []

    class Meta:
        db_table = "users"
        ordering = ["-date_joined"]

    def __str__(self) -> str:
        return f"{self.email} ({self.role})"

    # Convenience role checks used across the codebase.
    @property
    def is_parent(self) -> bool:
        return self.role == Role.PARENT

    @property
    def is_driver(self) -> bool:
        return self.role == Role.DRIVER

    @property
    def is_operator(self) -> bool:
        return self.role == Role.OPERATOR

    @property
    def is_admin_role(self) -> bool:
        return self.role == Role.ADMIN

    @property
    def is_accountant(self) -> bool:
        return self.role == Role.ACCOUNTANT


class ParentProfile(models.Model):
    user = models.OneToOneField(
        User, on_delete=models.CASCADE, related_name="parent_profile"
    )
    full_name = models.CharField(max_length=120)
    phone = models.CharField(max_length=32, blank=True)
    default_address = models.CharField(max_length=255, blank=True)
    photo = models.ImageField(upload_to="parents/", null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "parent_profiles"

    def __str__(self) -> str:
        return self.full_name


class SavedAddress(models.Model):
    """Reusable pickup/dropoff addresses (Дом, Школа №25 …)."""

    owner = models.ForeignKey(
        User, on_delete=models.CASCADE, related_name="saved_addresses"
    )
    label = models.CharField(max_length=64)
    text = models.CharField(max_length=255)
    lat = models.FloatField()
    lng = models.FloatField()
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "saved_addresses"
        ordering = ["label"]

    def __str__(self) -> str:
        return f"{self.label}: {self.text}"
