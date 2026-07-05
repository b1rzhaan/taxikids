"""Enrich demo data for the cabinet redesign:

1. Generate driver photos + licence card images (SVG placeholders).
2. Align DriverEarning.created_at with the trip date (auto_now_add put
   everything on "today", breaking weekly income charts).
3. Build weekly payout history per driver (older weeks paid, last pending).
4. Backfill route_polyline for historic trips so the map can draw
   trajectories.

Idempotent: safe to run repeatedly."""
import datetime as dt
import math
import random
from decimal import Decimal

from django.core.files.base import ContentFile
from django.core.management.base import BaseCommand
from django.utils import timezone

from apps.drivers.models import DriverProfile, Vehicle
from apps.payouts.models import DriverEarning, Payout, PayoutItem
from apps.trips.models import Trip

COLORS = ["#F5B800", "#E8A33D", "#D98E04", "#C97B0A"]


def _initials(name: str) -> str:
    parts = name.split()
    return "".join(p[0] for p in parts[:2]).upper()


def portrait_svg(name: str, color: str) -> str:
    ini = _initials(name)
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="320" height="320" viewBox="0 0 320 320">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0%" stop-color="#FFF6D6"/><stop offset="100%" stop-color="#FFCE00"/>
    </linearGradient>
  </defs>
  <rect width="320" height="320" fill="url(#bg)"/>
  <circle cx="160" cy="118" r="62" fill="{color}" opacity="0.9"/>
  <path d="M 48 320 Q 160 196 272 320 Z" fill="{color}" opacity="0.9"/>
  <circle cx="160" cy="118" r="62" fill="none" stroke="#15161A" stroke-opacity="0.08" stroke-width="3"/>
  <text x="160" y="136" text-anchor="middle" font-family="Arial, sans-serif"
        font-size="48" font-weight="bold" fill="#15161A" fill-opacity="0.85">{ini}</text>
</svg>"""


def license_svg(d: DriverProfile) -> str:
    expiry = (d.license_expiry or (timezone.localdate() + dt.timedelta(days=365 * 5)))
    issued = expiry - dt.timedelta(days=365 * 10)
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="640" height="400" viewBox="0 0 640 400">
  <rect width="640" height="400" rx="20" fill="#F7F8FA"/>
  <rect width="640" height="400" rx="20" fill="none" stroke="#D9DCE1" stroke-width="2"/>
  <rect x="0" y="0" width="640" height="64" rx="20" fill="#FFCE00"/>
  <rect x="0" y="32" width="640" height="32" fill="#FFCE00"/>
  <text x="24" y="40" font-family="Arial, sans-serif" font-size="20" font-weight="bold" fill="#15161A">ВОДИТЕЛЬСКОЕ УДОСТОВЕРЕНИЕ</text>
  <text x="616" y="40" text-anchor="end" font-family="Arial, sans-serif" font-size="13" fill="#15161A" fill-opacity="0.7">DRIVER LICENCE · KAZ</text>
  <rect x="24" y="88" width="150" height="190" rx="12" fill="#ECEEF1"/>
  <circle cx="99" cy="150" r="34" fill="#C9CDD3"/>
  <path d="M 40 278 Q 99 216 158 278 Z" fill="#C9CDD3"/>
  <text x="99" y="162" text-anchor="middle" font-family="Arial, sans-serif" font-size="26" font-weight="bold" fill="#15161A" fill-opacity="0.6">{_initials(d.full_name)}</text>
  <text x="198" y="110" font-family="Arial, sans-serif" font-size="12" fill="#8A8F98">1. ФАМИЛИЯ, ИМЯ / NAME</text>
  <text x="198" y="134" font-family="Arial, sans-serif" font-size="20" font-weight="bold" fill="#15161A">{d.full_name}</text>
  <text x="198" y="168" font-family="Arial, sans-serif" font-size="12" fill="#8A8F98">2. ИИН / PERSONAL ID</text>
  <text x="198" y="190" font-family="Arial, sans-serif" font-size="17" font-weight="bold" fill="#15161A">{d.iin or "—"}</text>
  <text x="198" y="224" font-family="Arial, sans-serif" font-size="12" fill="#8A8F98">5. НОМЕР / LICENCE No</text>
  <text x="198" y="246" font-family="Arial, sans-serif" font-size="17" font-weight="bold" fill="#15161A">{d.license_number or "—"}</text>
  <text x="420" y="224" font-family="Arial, sans-serif" font-size="12" fill="#8A8F98">9. КАТЕГОРИИ / CATEGORY</text>
  <text x="420" y="246" font-family="Arial, sans-serif" font-size="17" font-weight="bold" fill="#15161A">B, B1</text>
  <text x="198" y="280" font-family="Arial, sans-serif" font-size="12" fill="#8A8F98">4a. ВЫДАНО / ISSUED</text>
  <text x="198" y="300" font-family="Arial, sans-serif" font-size="15" font-weight="bold" fill="#15161A">{issued.strftime("%d.%m.%Y")}</text>
  <text x="420" y="280" font-family="Arial, sans-serif" font-size="12" fill="#8A8F98">4b. ДЕЙСТВИТЕЛЬНО ДО / EXPIRES</text>
  <text x="420" y="300" font-family="Arial, sans-serif" font-size="15" font-weight="bold" fill="#15161A">{expiry.strftime("%d.%m.%Y")}</text>
  <rect x="24" y="330" width="592" height="40" rx="10" fill="#FFF6D6"/>
  <text x="320" y="355" text-anchor="middle" font-family="Arial, sans-serif" font-size="13" fill="#8A8F98">ДЕМО-ДОКУМЕНТ · сгенерирован для стенда KidsTransfer</text>
</svg>"""


def fake_route(a, b, seed: int, n: int = 16):
    """A plausible curvy trajectory between two points (demo polyline)."""
    rng = random.Random(seed)
    dy, dx = b[0] - a[0], b[1] - a[1]
    length = math.hypot(dx, dy) or 1e-6
    ux, uy = -dy / length, dx / length  # perpendicular unit vector
    amp = length * rng.uniform(0.08, 0.16) * rng.choice([-1, 1])
    pts = []
    for i in range(n + 1):
        t = i / n
        lat = a[0] + dy * t
        lng = a[1] + dx * t
        bend = math.sin(t * math.pi) * amp
        jitter = length * 0.015 * rng.uniform(-1, 1) * math.sin(t * math.pi)
        pts.append([
            round(lat + uy * (bend + jitter), 6),
            round(lng + ux * (bend + jitter), 6),
        ])
    return pts


class Command(BaseCommand):
    help = "Add photos, payout history and route trajectories to demo data."

    def handle(self, *args, **options):
        self._photos()
        self._vehicles()
        self._fix_earning_dates()
        self._payout_history()
        self._backfill_routes()
        self.stdout.write(self.style.SUCCESS("Demo data enriched."))

    def _vehicles(self):
        """Fill in year / mileage / tech passport so the car card looks real."""
        rng = random.Random(7)
        fixed = 0
        for v in Vehicle.objects.all():
            changed = False
            if not v.year:
                v.year = rng.randint(2017, 2023)
                changed = True
            if not v.mileage_km:
                v.mileage_km = rng.randint(38000, 145000)
                changed = True
            if not v.tech_passport:
                v.tech_passport = f"KZ {rng.randint(100, 999)} {rng.randint(100000, 999999)}"
                changed = True
            if changed:
                v.save()
                fixed += 1
        self.stdout.write(f"vehicles enriched: {fixed}")

    def _photos(self):
        made = 0
        for i, d in enumerate(DriverProfile.objects.all()):
            if not d.photo:
                d.photo.save(
                    f"driver_{d.pk}.svg",
                    ContentFile(portrait_svg(d.full_name, COLORS[i % len(COLORS)])),
                    save=False,
                )
                made += 1
            if not d.license_photo:
                d.license_photo.save(
                    f"licence_{d.pk}.svg",
                    ContentFile(license_svg(d)),
                    save=False,
                )
                made += 1
            d.save()
        self.stdout.write(f"photos: {made} files generated")

    def _fix_earning_dates(self):
        fixed = 0
        for e in DriverEarning.objects.select_related("trip"):
            target = e.trip.scheduled_at + dt.timedelta(minutes=30)
            if abs((e.created_at - target).total_seconds()) > 3600:
                DriverEarning.objects.filter(pk=e.pk).update(created_at=target)
                fixed += 1
        self.stdout.write(f"earning dates aligned: {fixed}")

    def _payout_history(self):
        if Payout.objects.exists():
            self.stdout.write("payouts: already present, skipping")
            return
        created = 0
        today = timezone.localdate()
        for d in DriverProfile.objects.all():
            earnings = list(
                DriverEarning.objects.filter(
                    driver=d, status=DriverEarning.Status.ACCRUED
                ).select_related("trip")
            )
            by_week: dict[dt.date, list] = {}
            for e in earnings:
                day = e.trip.scheduled_at.date()
                week_start = day - dt.timedelta(days=day.weekday())
                by_week.setdefault(week_start, []).append(e)
            weeks = sorted(by_week)
            for wi, week_start in enumerate(weeks):
                items = by_week[week_start]
                is_last = wi == len(weeks) - 1
                total = sum(Decimal(e.amount) for e in items)
                payout = Payout.objects.create(
                    driver=d,
                    period_start=week_start,
                    period_end=week_start + dt.timedelta(days=6),
                    total_amount=total,
                    status=Payout.Status.PENDING if is_last else Payout.Status.PAID,
                    paid_at=None if is_last else timezone.make_aware(
                        dt.datetime.combine(
                            min(week_start + dt.timedelta(days=7), today),
                            dt.time(12, 0),
                        )
                    ),
                )
                for e in items:
                    PayoutItem.objects.create(payout=payout, earning=e)
                    if not is_last:
                        DriverEarning.objects.filter(pk=e.pk).update(
                            status=DriverEarning.Status.INCLUDED
                        )
                created += 1
        self.stdout.write(f"payouts created: {created}")

    def _backfill_routes(self):
        fixed = 0
        for t in Trip.objects.all():
            if t.route_polyline and len(t.route_polyline) > 2:
                continue
            t.route_polyline = fake_route(
                (t.pickup_lat, t.pickup_lng),
                (t.dropoff_lat, t.dropoff_lng),
                seed=t.pk,
            )
            t.save(update_fields=["route_polyline"])
            fixed += 1
        self.stdout.write(f"routes backfilled: {fixed}")
