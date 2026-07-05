"""Seed ~30 days of ride history so the dashboard chart and the trips
history page have realistic data (routes, payments, earnings, ratings).

Idempotent: skips when enough completed trips already exist (use --force)."""
import datetime as dt
import random
import uuid
from decimal import Decimal

from django.core.management.base import BaseCommand
from django.utils import timezone

from apps.accounts.models import ParentProfile, Role, User
from apps.children.models import Child
from apps.drivers.models import DriverProfile, SalaryScheme, Tariff, Vehicle
from apps.payments.models import Payment
from apps.payouts.models import DriverEarning
from apps.trips.models import Trip, TripRating, TripStatus

ADDRESSES = [
    ("ул. Абая, 45", 43.2389, 76.8897),
    ("Школа №25, ул. Мира, 15", 43.2565, 76.9285),
    ("мкр. Самал-2, 33", 43.2333, 76.9552),
    ("Гимназия №5, пр. Достык, 118", 43.2255, 76.9575),
    ("ул. Тимирязева, 42", 43.2360, 76.9086),
    ("Лицей №134, ул. Жандосова, 6", 43.2266, 76.8968),
    ("мкр. Орбита-3, 21", 43.2019, 76.8734),
    ("Школа №105, ул. Розыбакиева, 72", 43.2214, 76.8899),
]

COMMENTS = [
    "Всё отлично, спасибо!",
    "Водитель приехал вовремя",
    "Ребёнок доволен поездкой",
    "Аккуратное вождение",
    "Отличный сервис",
    "",
]

EXTRA_DRIVERS = [
    ("driver2@kids.kz", "Марат Досжанов", "+7 702 000 0002",
     "990202300456", "CD2345678", "4.85", 9, "B234CD02", "Hyundai", "Accent"),
    ("driver3@kids.kz", "Сергей Ким", "+7 703 000 0003",
     "850303300789", "EF3456789", "4.75", 5, "C345DE02", "Toyota", "Corolla"),
    ("driver4@kids.kz", "Айгерим Нурланова", "+7 704 000 0004",
     "920404400321", "GH4567890", "4.95", 6, "D456EF02", "Kia", "Cerato"),
]


class Command(BaseCommand):
    help = "Generate demo ride history for the last N days."

    def add_arguments(self, parser):
        parser.add_argument("--days", type=int, default=30)
        parser.add_argument("--force", action="store_true")

    def handle(self, *args, **options):
        if (
            not options["force"]
            and Trip.objects.filter(status=TripStatus.COMPLETED).count() >= 15
        ):
            self.stdout.write("History already present, skipping (use --force).")
            return

        parent = ParentProfile.objects.first()
        child = Child.objects.first()
        tariff = Tariff.objects.filter(is_active=True).first()
        scheme = SalaryScheme.objects.first()
        if not (parent and child and tariff):
            self.stderr.write("Run seed_demo first.")
            return

        self._extra_drivers(scheme)
        drivers = list(DriverProfile.objects.all())

        rng = random.Random(42)
        now = timezone.now()
        created = 0
        for day in range(options["days"], 0, -1):
            for _ in range(rng.randint(1, 4)):
                a, b = rng.sample(ADDRESSES, 2)
                sched = now - dt.timedelta(days=day, minutes=rng.randint(0, 600))
                dist = rng.randint(3000, 15000)
                dur = int(dist / rng.uniform(6.5, 9.0))
                price = Decimal(
                    max(1000, 500 + dist // 1000 * 120 + dur // 60 * 20)
                )
                completed = rng.random() > 0.12
                status = TripStatus.COMPLETED if completed else TripStatus.CANCELLED
                driver = rng.choice(drivers)
                trip = Trip.objects.create(
                    parent=parent, child=child, tariff=tariff,
                    driver=driver if completed else None,
                    pickup_text=a[0], pickup_lat=a[1], pickup_lng=a[2],
                    dropoff_text=b[0], dropoff_lat=b[1], dropoff_lng=b[2],
                    scheduled_at=sched,
                    route_distance_m=dist, route_duration_s=dur,
                    price_amount=price,
                    status=status,
                    payment_status="paid" if completed else "unpaid",
                    driver_earning_amount=(
                        price * Decimal("0.70") if completed else Decimal("0")
                    ),
                )
                if completed:
                    Payment.objects.create(
                        trip=trip, parent=parent,
                        provider=rng.choice(["halyk", "mock"]),
                        provider_ref=f"hist_{uuid.uuid4().hex[:12]}",
                        amount=price, status=Payment.Status.SUCCESS,
                        idempotency_key=uuid.uuid4().hex,
                        paid_at=sched + dt.timedelta(minutes=5),
                    )
                    DriverEarning.objects.create(
                        trip=trip, driver=driver,
                        amount=trip.driver_earning_amount,
                    )
                    if rng.random() > 0.25:
                        TripRating.objects.create(
                            trip=trip, role="parent",
                            stars=rng.choices([5, 4, 3], [0.7, 0.25, 0.05])[0],
                            comment=rng.choice(COMMENTS),
                        )
                created += 1
        self.stdout.write(self.style.SUCCESS(f"Created {created} historic trips."))

    def _extra_drivers(self, scheme):
        """A few more drivers so the leaderboard looks real."""
        for (email, name, phone, iin, lic, rating, exp,
             plate, make, model) in EXTRA_DRIVERS:
            user, was_created = User.objects.get_or_create(
                email=email, defaults={"role": Role.DRIVER}
            )
            if was_created:
                user.set_password("driver12345")
                user.save()
            profile, _ = DriverProfile.objects.get_or_create(
                user=user,
                defaults={
                    "full_name": name, "phone": phone, "iin": iin,
                    "license_number": lic,
                    "doc_status": DriverProfile.DocStatus.APPROVED,
                    "experience_years": exp, "has_child_seat": True,
                    "rating": Decimal(rating), "salary_scheme": scheme,
                    "hired_at": timezone.localdate(),
                },
            )
            Vehicle.objects.get_or_create(
                plate_number=plate,
                defaults={"driver": profile, "make": make, "model": model,
                          "color": "Белый", "seats": 4},
            )
