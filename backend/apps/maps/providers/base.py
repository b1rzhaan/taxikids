"""Port (interface) for map providers — the swappable boundary.

Any concrete provider (2GIS, Google, Yandex, OSRM, Mock) implements MapProvider.
The rest of the system depends only on this interface, never on a vendor SDK.
"""
from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass, field


@dataclass(frozen=True)
class Point:
    lat: float
    lng: float

    def as_tuple(self) -> tuple[float, float]:
        return (self.lat, self.lng)


@dataclass
class GeocodeResult:
    text: str
    point: Point


@dataclass
class Route:
    distance_m: int
    duration_s: int          # duration WITHOUT traffic
    duration_traffic_s: int  # duration WITH live traffic (== duration_s if N/A)
    polyline: list[list[float]] = field(default_factory=list)  # [[lat,lng], ...]
    provider: str = ""
    has_traffic: bool = False


class MapProvider(ABC):
    """All coordinates are WGS84 (lat, lng)."""

    name: str = "base"

    @abstractmethod
    def geocode(self, text: str) -> GeocodeResult | None:
        """Address string -> coordinates."""

    @abstractmethod
    def reverse_geocode(self, lat: float, lng: float) -> str | None:
        """Coordinates -> human-readable address."""

    @abstractmethod
    def route(self, origin: Point, dest: Point) -> Route:
        """Build a driving route with distance, duration and (if available) traffic."""

    def suggest(self, text: str) -> list[GeocodeResult]:
        """Address autocomplete — multiple candidates for a partial query.

        Default falls back to a single geocode; providers override for
        real multi-result suggestions."""
        r = self.geocode(text)
        return [r] if r else []
