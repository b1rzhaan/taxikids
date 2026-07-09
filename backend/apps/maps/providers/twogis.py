"""2GIS Platform adapter.

Docs: https://docs.2gis.com/en/api/navigation/directions/overview
      https://docs.2gis.com/en/api/search/geocoder/overview

Requires TWOGIS_API_KEY. Geocoding and traffic-aware routing are paid Platform
APIs (there is a free trial / limited quota). If a request fails we raise
MapProviderError; callers may fall back to the mock provider.
"""
from __future__ import annotations

import logging

import requests
from django.conf import settings

from .base import GeocodeResult, MapProvider, Point, Route

logger = logging.getLogger(__name__)


class MapProviderError(RuntimeError):
    pass


class TwoGisProvider(MapProvider):
    name = "twogis"

    def __init__(self):
        self.key = settings.TWOGIS_API_KEY
        self.routing_url = settings.TWOGIS_BASE_URL.rstrip("/")
        self.catalog_url = settings.TWOGIS_CATALOG_URL.rstrip("/")
        # Proximity bias (lon,lat) so results rank near the service city.
        self.bias = f"{settings.MAP_BIAS_LNG},{settings.MAP_BIAS_LAT}"
        if not self.key:
            raise MapProviderError("TWOGIS_API_KEY is not configured")

    # ── Geocoding ─────────────────────────────────────────────────────
    def _fetch_items(self, params: dict) -> list[dict]:
        url = f"{self.catalog_url}/3.0/items/geocode"
        params = {
            **params,
            "fields": "items.point",
            "location": self.bias,
            "key": self.key,
        }
        try:
            resp = requests.get(url, params=params, timeout=15)
            resp.raise_for_status()
            return resp.json().get("result", {}).get("items", [])
        except (requests.RequestException, ValueError) as exc:
            logger.warning("2GIS geocode failed: %s", exc)
            raise MapProviderError(str(exc)) from exc

    @staticmethod
    def _to_result(item: dict) -> GeocodeResult | None:
        pt = item.get("point")
        if not pt:
            return None
        return GeocodeResult(
            text=item.get("full_name") or item.get("name", ""),
            point=Point(lat=pt["lat"], lng=pt["lon"]),
        )

    def geocode(self, text: str) -> GeocodeResult | None:
        items = self._fetch_items({"q": text})
        for item in items:
            r = self._to_result(item)
            if r:
                return r
        return None

    def suggest(self, text: str) -> list[GeocodeResult]:
        items = self._fetch_items({"q": text})
        results = [self._to_result(i) for i in items]
        return [r for r in results if r is not None]

    def reverse_geocode(self, lat: float, lng: float) -> str | None:
        # type=building+radius returns the nearest building (street + house),
        # otherwise 2GIS returns only broad districts (adm_div).
        items = self._reverse_items(lat, lng, {"type": "building", "radius": 200})
        for item in items:
            name = item.get("address_name") or item.get("full_name") or item.get("name")
            if name:
                return name
        if not items:
            items = self._reverse_items(lat, lng, {"radius": 600})
        for item in items:
            name = item.get("address_name") or item.get("full_name") or item.get("name")
            if name:
                return name
        return None

    def _reverse_items(self, lat: float, lng: float, extra: dict | None = None) -> list[dict]:
        url = f"{self.catalog_url}/3.0/items/geocode"
        params = {
            "lat": lat,
            "lon": lng,
            "fields": "items.point,items.full_name,items.address,items.address_name",
            "key": self.key,
            **(extra or {}),
        }
        try:
            resp = requests.get(url, params=params, timeout=15)
            resp.raise_for_status()
            return resp.json().get("result", {}).get("items", [])
        except (requests.RequestException, ValueError) as exc:
            logger.warning("2GIS reverse geocode failed: %s", exc)
            raise MapProviderError(str(exc)) from exc

    # ── Routing (traffic-aware) ───────────────────────────────────────
    def route(self, origin: Point, dest: Point) -> Route:
        # Routing API 7.0.0 (current). carrouting/6.0.0 is deprecated.
        url = f"{self.routing_url}/routing/7.0.0/global"
        body = {
            "locale": "ru",
            "points": [
                {"type": "stop", "lat": origin.lat, "lon": origin.lng},
                {"type": "stop", "lat": dest.lat, "lon": dest.lng},
            ],
            "transport": "driving",
            "route_mode": "fastest",
            "traffic_mode": "jam",  # take live traffic (пробки) into account
            "output": "detailed",
        }
        try:
            resp = requests.post(
                url, params={"key": self.key}, json=body, timeout=12
            )
            resp.raise_for_status()
            data = resp.json()
        except (requests.RequestException, ValueError) as exc:
            logger.warning("2GIS routing failed: %s", exc)
            raise MapProviderError(str(exc)) from exc

        routes = data.get("result") or []
        if isinstance(routes, dict):  # some responses wrap in a single object
            routes = [routes]
        if not routes:
            # Surface 2GIS's own error message if present.
            msg = data.get("message") or data.get("status") or "no route"
            raise MapProviderError(f"2GIS returned no route: {msg}")
        r = routes[0]
        distance_m = int(r.get("total_distance", 0))
        duration_traffic_s = int(r.get("total_duration", 0))
        return Route(
            distance_m=distance_m,
            duration_s=duration_traffic_s,
            duration_traffic_s=duration_traffic_s,
            polyline=self._extract_polyline(r),
            provider=self.name,
            has_traffic=True,
        )

    @staticmethod
    def _extract_polyline(route_obj: dict) -> list[list[float]]:
        """Best-effort geometry extraction; shape varies by API version."""
        points: list[list[float]] = []
        for maneuver in route_obj.get("maneuvers", []):
            geom = maneuver.get("outcoming_path", {}).get("geometry", [])
            for seg in geom:
                selection = seg.get("selection", "")
                # 2GIS returns WKT LINESTRING; parse lightly.
                if selection.startswith("LINESTRING"):
                    coords = selection[selection.find("(") + 1: selection.find(")")]
                    for pair in coords.split(","):
                        lon, lat = pair.strip().split(" ")
                        points.append([float(lat), float(lon)])
        return points
