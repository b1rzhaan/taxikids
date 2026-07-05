"""Provider factory + high-level map operations used across the app."""
from __future__ import annotations

from functools import lru_cache

from django.conf import settings

from .providers.base import MapProvider, Point, Route
from .providers.mock import MockMapProvider


@lru_cache(maxsize=None)
def get_map_provider() -> MapProvider:
    """Return the configured MapProvider. Swap providers via MAP_PROVIDER env."""
    provider = settings.MAP_PROVIDER.lower()
    if provider == "twogis":
        from .providers.twogis import TwoGisProvider

        return TwoGisProvider()
    return MockMapProvider()


def safe_route(origin: Point, dest: Point) -> Route:
    """Build a route, falling back to the mock provider if the real one fails."""
    provider = get_map_provider()
    try:
        return provider.route(origin, dest)
    except Exception:  # noqa: BLE001 — any provider/network error → graceful demo
        return MockMapProvider().route(origin, dest)
