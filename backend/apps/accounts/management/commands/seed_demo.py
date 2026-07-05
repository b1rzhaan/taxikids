"""Seed a realistic demo dataset so the app is usable immediately.

Idempotent: uses get_or_create. Pass --if-empty to skip when users already exist
(used by docker-compose so restarts don't error)."""
import datetime as dt
from decimal import Decimal

from django.core.management.base import BaseCommand
from django.utils import timezone

from apps.accounts.models import ParentProfile, Role, SavedAddress, User
from apps.children.models import Child
from apps.drivers.models import DriverProfile, SalaryScheme, Tariff, Vehicle
from apps.trips.models import Trip, TripStatus
from apps.trips.services import build_route_for_trip
from apps.wallet.models import SubscriptionPlan
from apps.wallet.services import get_or_create_wallet, credit
from apps.wallet.models import WalletTransaction

PWD = {
    "admin": "admin12345",
    "operator": "operator12345",
    "accountant": "accountant12345",
    "driver": "driver12345",
    "parent": "parent12345",
}


class Command(BaseCommand):
    help = "Create demo users, drivers, tariffs, children and sample trips."

    def add_arguments(self, parser):
        parser.add_argument("--if-empty", action="store_true")

    def handle(self, *args, **options):
        if options["if_empty"] and User.objects.exclude(is_superuser=True).exists():
            self.stdout.write("Data already present, skipping seed.")
            return

        # ── Staff ─────────────────────────────────────────────────────
        admin = self._user("admin@kids.kz", Role.ADMIN, PWD["admin"],
                            is_staff=True, is_superuser=True)
        self._user("operator@kids.kz", Role.OPERATOR, PWD["operator"], is_staff=True)
        self._user("accountant@kids.kz", Role.ACCOUNTANT, PWD["accountant"], is_staff=True)

        # ── Pricing & salary ──────────────────────────────────────────
        scheme, _ = SalaryScheme.objects.get_or_create(
            name="70% с поездки",
            defaults={"type": SalaryScheme.Type.PERCENT, "value": Decimal("0.70")},
        )
        tariff, _ = Tariff.objects.get_or_create(
            name="Базовый",
            defaults={
                "base_fare": Decimal("500"), "per_km": Decimal("120"),
                "per_min": Decimal("20"), "min_fare": Decimal("1000"),
            },
        )

        # ── Drivers + vehicles ────────────────────────────────────────
        d_user = self._user("driver@kids.kz", Role.DRIVER, PWD["driver"])
        driver, _ = DriverProfile.objects.get_or_create(
            user=d_user,
            defaults={
                "full_name": "Алексей Иванов", "phone": "+7 701 000 0001",
                "iin": "800101300123", "license_number": "AB1234567",
                "doc_status": DriverProfile.DocStatus.APPROVED,
                "experience_years": 7, "has_child_seat": True,
                "rating": Decimal("4.90"), "salary_scheme": scheme,
                "hired_at": timezone.localdate(),
            },
        )
        Vehicle.objects.get_or_create(
            plate_number="A123BC77",
            defaults={"driver": driver, "make": "Kia", "model": "Rio",
                      "color": "Белый", "seats": 4},
        )

        # ── Parent + children + wallet ────────────────────────────────
        p_user = self._user("parent@kids.kz", Role.PARENT, PWD["parent"],
                            phone="+7 701 111 2233")
        parent, _ = ParentProfile.objects.get_or_create(
            user=p_user,
            defaults={"full_name": "Мама Маши", "phone": "+7 701 111 2233"},
        )
        child, _ = Child.objects.get_or_create(
            parent=parent, full_name="Маша",
            defaults={"birth_date": dt.date(2017, 5, 1), "school": "Школа №25",
                      "note_for_driver": "Забирать у второго подъезда"},
        )
        wallet = get_or_create_wallet(parent)
        if wallet.balance == 0:
            credit(parent, Decimal("15000"), WalletTransaction.Kind.TOPUP,
                   note="Стартовый баланс (демо)")

        SavedAddress.objects.get_or_create(
            owner=p_user, label="Дом",
            defaults={"text": "ул. Абая, 45", "lat": 43.2389, "lng": 76.8897},
        )
        SavedAddress.objects.get_or_create(
            owner=p_user, label="Школа №25",
            defaults={"text": "ул. Мира, 15", "lat": 43.2565, "lng": 76.9285},
        )

        # ── Subscription plan (месячный абонемент) ────────────────────
        SubscriptionPlan.objects.get_or_create(
            name="Месячный (30 поездок)",
            defaults={"trips_count": 30, "price": Decimal("90000"), "duration_days": 30},
        )

        # ── A couple of sample trips ──────────────────────────────────
        self._sample_trip(parent, child, tariff, driver, TripStatus.CREATED)
        self._sample_trip(parent, child, tariff, driver, TripStatus.COMPLETED)

        self.stdout.write(self.style.SUCCESS("Demo data seeded."))
        self.stdout.write("Logins (password): "
                          "admin@kids.kz/admin12345, operator@kids.kz/operator12345, "
                          "accountant@kids.kz/accountant12345, driver@kids.kz/driver12345, "
                          "parent@kids.kz/parent12345")

    # ── helpers ──────────────────────────────────────────────────────
    def _user(self, email, role, password, **extra):
        user, created = User.objects.get_or_create(
            email=email, defaults={"role": role, **extra}
        )
        if created:
            user.set_password(password)
            for k, v in extra.items():
                setattr(user, k, v)
            user.save()
        return user

    def _sample_trip(self, parent, child, tariff, driver, status):
        exists = Trip.objects.filter(parent=parent, status=status).exists()
        if exists:
            return
        trip = Trip(
            parent=parent, child=child, tariff=tariff,
            pickup_text="ул. Абая, 45", pickup_lat=43.2389, pickup_lng=76.8897,
            dropoff_text="Школа №25, ул. Мира, 15", dropoff_lat=43.2565, dropoff_lng=76.9285,
            scheduled_at=timezone.now() + dt.timedelta(hours=1),
            status=status,
        )
        build_route_for_trip(trip)
        if status == TripStatus.COMPLETED:
            trip.driver = driver
            trip.payment_status = "paid"
            trip.driver_earning_amount = (trip.price_amount * Decimal("0.70"))
        trip.save()
        if status == TripStatus.COMPLETED:
            import uuid

            from django.utils import timezone as tz

            from apps.payments.models import Payment
            from apps.payouts.models import DriverEarning

            # Successful payment so revenue reconciles with driver expense.
            Payment.objects.get_or_create(
                trip=trip,
                defaults={
                    "parent": parent, "provider": "mock",
                    "provider_ref": f"seed_{uuid.uuid4().hex[:12]}",
                    "amount": trip.price_amount, "status": Payment.Status.SUCCESS,
                    "idempotency_key": uuid.uuid4().hex, "paid_at": tz.now(),
                },
            )
            DriverEarning.objects.get_or_create(
                trip=trip, defaults={"driver": driver,
                                     "amount": trip.driver_earning_amount},
            )
