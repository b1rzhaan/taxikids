"""Deterministic offline provider — lets us build & demo the whole system
without any API key or network. Distances use the haversine formula; a
pseudo-random but stable 'traffic' factor is derived from the coordinates."""
from __future__ import annotations

import math

from .base import GeocodeResult, MapProvider, Point, Route

# A few known Almaty landmarks so geocoding of demo addresses returns sane points.
_KNOWN = {
    "дом": Point(43.2389, 76.8897),
    "школа": Point(43.2565, 76.9285),
    "школа №25": Point(43.2565, 76.9285),
    "садик": Point(43.2200, 76.8500),
    "центр": Point(43.2380, 76.9450),
}
_DEFAULT = Point(43.2380, 76.9450)  # Almaty center

# Canned Almaty addresses for offline autocomplete suggestions.
_SUGGEST_DB = [
    ("Алматы, проспект Абая, 45", Point(43.2389, 76.8897)),
    ("Алматы, проспект Абая, 150", Point(43.2376, 76.8840)),
    ("Алматы, улица Мира, 15 — Школа №25", Point(43.2565, 76.9285)),
    ("Алматы, улица Толе би, 59", Point(43.2560, 76.9300)),
    ("Алматы, микрорайон Самал-2, 33", Point(43.2200, 76.9300)),
    ("Алматы, ТРЦ Mega, Розыбакиева 247а", Point(43.2010, 76.8990)),
    ("Алматы, улица Достык, 91", Point(43.2330, 76.9560)),
    ("Алматы, детский сад «Балбобек», Сатпаева 90", Point(43.2400, 76.9100)),
]


def _haversine_m(a: Point, b: Point) -> float:
    r = 6371000.0
    p1, p2 = math.radians(a.lat), math.radians(b.lat)
    dphi = math.radians(b.lat - a.lat)
    dl = math.radians(b.lng - a.lng)
    h = math.sin(dphi / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * r * math.asin(math.sqrt(h))


class MockMapProvider(MapProvider):
    name = "mock"

    def geocode(self, text: str) -> GeocodeResult | None:
        key = (text or "").strip().lower()
        point = next((p for k, p in _KNOWN.items() if k in key), _DEFAULT)
        return GeocodeResult(text=text, point=point)

    def reverse_geocode(self, lat: float, lng: float) -> str | None:
        return f"Демо-адрес ({lat:.5f}, {lng:.5f})"

    def suggest(self, text: str) -> list[GeocodeResult]:
        q = (text or "").strip().lower()
        matches = [
            GeocodeResult(text=t, point=p)
            for t, p in _SUGGEST_DB
            if not q or q in t.lower()
        ]
        return matches[:6] if matches else [
            GeocodeResult(text=text or "Точка", point=_DEFAULT)
        ]

    def route(self, origin: Point, dest: Point) -> Route:
        straight = _haversine_m(origin, dest)
        # Roads are longer than straight line; add ~30%.
        distance_m = int(straight * 1.3) or 500
        # Assume ~24 km/h average city speed.
        base_speed_mps = 24_000 / 3600
        duration_s = int(distance_m / base_speed_mps)
        # Stable pseudo-traffic factor 1.0..1.6 from coordinates.
        seed = (abs(origin.lat) + abs(dest.lng)) * 1000
        traffic_factor = 1.0 + (int(seed) % 60) / 100.0
        duration_traffic_s = int(duration_s * traffic_factor)
        polyline = [[origin.lat, origin.lng], [dest.lat, dest.lng]]
        return Route(
            distance_m=distance_m,
            duration_s=duration_s,
            duration_traffic_s=duration_traffic_s,
            polyline=polyline,
            provider=self.name,
            has_traffic=True,
        )
