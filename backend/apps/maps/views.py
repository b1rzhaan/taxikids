from decimal import Decimal

from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.drivers.models import Tariff

from .providers.base import Point
from .services import get_map_provider, safe_route


class MapConfigView(APIView):
    """GET /api/maps/config/ → client map config (2GIS MapGL JS key)."""

    def get(self, request):
        from django.conf import settings

        return Response({
            "provider": settings.MAP_PROVIDER,
            # MapGL JS uses the same 2GIS Platform key as our REST calls.
            "twogis_map_key": settings.TWOGIS_API_KEY,
        })


class GeocodeView(APIView):
    """GET /api/maps/geocode/?q=Школа №25 → address + coordinates."""

    def get(self, request):
        q = request.query_params.get("q", "").strip()
        if not q:
            return Response({"detail": "q is required"}, status=400)
        result = get_map_provider().geocode(q)
        if not result:
            return Response({"detail": "not found"}, status=404)
        return Response(
            {
                "text": result.text,
                "lat": result.point.lat,
                "lng": result.point.lng,
            }
        )


class SuggestView(APIView):
    """GET /api/maps/suggest/?q=Абая → [{text, lat, lng}] autocomplete list."""

    def get(self, request):
        q = request.query_params.get("q", "").strip()
        if len(q) < 2:
            return Response([])
        try:
            results = get_map_provider().suggest(q)
        except Exception:  # noqa: BLE001 — fall back to mock suggestions
            from .providers.mock import MockMapProvider

            results = MockMapProvider().suggest(q)
        return Response([
            {"text": r.text, "lat": r.point.lat, "lng": r.point.lng}
            for r in results
        ])


class ReverseGeocodeView(APIView):
    """GET /api/maps/reverse/?lat=..&lng=.. → address string."""

    def get(self, request):
        try:
            lat = float(request.query_params["lat"])
            lng = float(request.query_params["lng"])
        except (KeyError, ValueError):
            return Response({"detail": "lat & lng required"}, status=400)
        text = get_map_provider().reverse_geocode(lat, lng)
        return Response({"text": text, "lat": lat, "lng": lng})


class RouteView(APIView):
    """POST /api/maps/route/ {origin:{lat,lng}, dest:{lat,lng}} → route + traffic."""

    def post(self, request):
        origin, dest = _parse_points(request.data)
        if origin is None:
            return Response({"detail": "origin & dest required"}, status=400)
        route = safe_route(origin, dest)
        return Response(_route_payload(route))


class EstimateView(APIView):
    """POST /api/maps/estimate/ {origin, dest, tariff_id?} → route + price preview."""

    def post(self, request):
        origin, dest = _parse_points(request.data)
        if origin is None:
            return Response({"detail": "origin & dest required"}, status=400)
        route = safe_route(origin, dest)

        tariff = None
        tariff_id = request.data.get("tariff_id")
        if tariff_id:
            tariff = Tariff.objects.filter(pk=tariff_id, is_active=True).first()
        if tariff is None:
            tariff = Tariff.objects.filter(is_active=True).first()

        price = (
            tariff.price_for(route.distance_m, route.duration_traffic_s)
            if tariff
            else Decimal("0")
        )
        payload = _route_payload(route)
        payload.update({
            "tariff_id": tariff.id if tariff else None,
            "price": price,
            "currency": "KZT",
        })
        return Response(payload, status=status.HTTP_200_OK)


def _parse_points(data):
    try:
        o = data["origin"]
        d = data["dest"]
        return Point(float(o["lat"]), float(o["lng"])), Point(
            float(d["lat"]), float(d["lng"])
        )
    except (KeyError, TypeError, ValueError):
        return None, None


def _route_payload(route) -> dict:
    return {
        "distance_m": route.distance_m,
        "distance_km": round(route.distance_m / 1000, 1),
        "duration_s": route.duration_s,
        "duration_traffic_s": route.duration_traffic_s,
        "duration_min": round(route.duration_traffic_s / 60),
        "has_traffic": route.has_traffic,
        "provider": route.provider,
        "polyline": route.polyline,
    }
