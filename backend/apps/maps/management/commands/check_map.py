"""Verify the configured map provider end-to-end (geocoding + traffic routing).

Usage:
    python manage.py check_map
    python manage.py check_map --q "Алматы, Абая 45" --from 43.2389,76.8897 --to 43.2565,76.9285

Set MAP_PROVIDER=twogis and TWOGIS_API_KEY in .env to test the real 2GIS API.
"""
from django.conf import settings
from django.core.management.base import BaseCommand

from apps.maps.providers.base import Point
from apps.maps.services import get_map_provider


class Command(BaseCommand):
    help = "Smoke-test the configured MapProvider (geocode + traffic-aware route)."

    def add_arguments(self, parser):
        parser.add_argument("--q", default="Алматы, проспект Абая 45")
        parser.add_argument("--from", dest="origin", default="43.2389,76.8897")
        parser.add_argument("--to", dest="dest", default="43.2565,76.9285")

    def handle(self, *args, **opts):
        self.stdout.write(f"MAP_PROVIDER = {settings.MAP_PROVIDER}")
        if settings.MAP_PROVIDER == "twogis":
            key = settings.TWOGIS_API_KEY
            self.stdout.write(
                "TWOGIS_API_KEY = " + (f"{key[:6]}…({len(key)} chars)" if key else "MISSING")
            )
        provider = get_map_provider()

        # ── Geocoding ─────────────────────────────────────────────────
        self.stdout.write(self.style.HTTP_INFO(f"\n[geocode] '{opts['q']}'"))
        try:
            g = provider.geocode(opts["q"])
            if g:
                self.stdout.write(
                    self.style.SUCCESS(
                        f"  -> {g.text} @ ({g.point.lat:.5f}, {g.point.lng:.5f})"
                    )
                )
            else:
                self.stdout.write(self.style.WARNING("  -> not found"))
        except Exception as exc:  # noqa: BLE001
            self.stdout.write(self.style.ERROR(f"  geocode error: {exc}"))

        # ── Routing with traffic ──────────────────────────────────────
        o = _pt(opts["origin"])
        d = _pt(opts["dest"])
        self.stdout.write(
            self.style.HTTP_INFO(f"\n[route] {opts['origin']} -> {opts['dest']}")
        )
        try:
            r = provider.route(o, d)
            self.stdout.write(self.style.SUCCESS(
                f"  distance: {r.distance_m/1000:.1f} km\n"
                f"  duration (no traffic): {r.duration_s//60} min\n"
                f"  duration (with пробки): {r.duration_traffic_s//60} min\n"
                f"  has_traffic: {r.has_traffic} | provider: {r.provider} | "
                f"polyline points: {len(r.polyline)}"
            ))
            self.stdout.write(self.style.SUCCESS("\nMAP PROVIDER OK"))
        except Exception as exc:  # noqa: BLE001
            self.stdout.write(self.style.ERROR(f"  route error: {exc}"))
            self.stdout.write(
                "\nHint: убедись, что ключ активирован и у него включены продукты "
                "'Routing API' и 'Geocoder/Places API' в личном кабинете 2GIS."
            )


def _pt(s: str) -> Point:
    lat, lng = (float(x) for x in s.split(","))
    return Point(lat, lng)
