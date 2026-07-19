"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import maplibregl, { type GeoJSONSource, type LngLatBoundsLike, type Marker } from "maplibre-gl";
import "maplibre-gl/dist/maplibre-gl.css";
import type { Feature, FeatureCollection, LineString } from "geojson";
import type { DriverLocation, Trip } from "@/lib/types";

const MAP_STYLE: maplibregl.StyleSpecification = {
  version: 8,
  sources: {
    osm: {
      type: "raster",
      tiles: ["https://tile.openstreetmap.org/{z}/{x}/{y}.png"],
      tileSize: 256,
      attribution: "© OpenStreetMap contributors",
    },
  },
  layers: [{ id: "osm", type: "raster", source: "osm" }],
};

function softenRoute(path: [number, number][]): [number, number][] {
  if (path.length !== 2) return path;
  const [a, b] = path;
  const latDelta = b[0] - a[0];
  const lngDelta = b[1] - a[1];
  const sign = a[0] + a[1] < b[0] + b[1] ? 1 : -1;
  const bendLat = Math.min(Math.max(Math.abs(lngDelta) * 0.18, 0.004), 0.018) * sign;
  const bendLng = Math.min(Math.max(Math.abs(latDelta) * 0.18, 0.004), 0.018) * -sign;
  return [
    a,
    [a[0] + latDelta * 0.18, a[1]],
    [(a[0] + b[0]) / 2 + bendLat, (a[1] + b[1]) / 2 + bendLng],
    [b[0] - latDelta * 0.18, b[1]],
    b,
  ];
}

export interface DriverPos {
  tripId: number;
  lat: number;
  lng: number;
}

export default function LiveMap({
  trips,
  driverPositions,
  center = [43.238, 76.912],
  scrollZoom = true,
  path,
  taxis = [],
}: {
  trips: Trip[];
  driverPositions: DriverPos[];
  center?: [number, number];
  scrollZoom?: boolean;
  /** Selected trip trajectory: [[lat, lng], ...] */
  path?: [number, number][];
  /** Live taxis on the line (real-time tracking). */
  taxis?: DriverLocation[];
}) {
  const containerRef = useRef<HTMLDivElement | null>(null);
  const mapRef = useRef<maplibregl.Map | null>(null);
  const markersRef = useRef<Marker[]>([]);
  const [ready, setReady] = useState(false);

  const displayPath = useMemo(
    () => (path && path.length > 1 ? softenRoute(path) : undefined),
    [path]
  );

  useEffect(() => {
    if (!containerRef.current || mapRef.current) return;

    const map = new maplibregl.Map({
      container: containerRef.current,
      style: MAP_STYLE,
      center: [center[1], center[0]],
      zoom: 12,
      attributionControl: { compact: true },
    });
    mapRef.current = map;

    if (!scrollZoom) map.scrollZoom.disable();
    map.addControl(new maplibregl.NavigationControl({ visualizePitch: true }), "top-left");
    map.on("load", () => {
      map.addSource("routes", {
        type: "geojson",
        data: emptyRouteCollection(),
      });
      map.addLayer({
        id: "route-casing",
        type: "line",
        source: "routes",
        paint: {
          "line-color": "#111827",
          "line-width": 7,
          "line-opacity": 0.22,
          "line-blur": 0.4,
        },
        layout: { "line-cap": "round", "line-join": "round" },
      });
      map.addLayer({
        id: "route-line",
        type: "line",
        source: "routes",
        paint: {
          "line-color": "#F5B800",
          "line-width": 4.5,
          "line-opacity": 0.95,
        },
        layout: { "line-cap": "round", "line-join": "round" },
      });
      setReady(true);
    });

    return () => {
      markersRef.current.forEach((marker) => marker.remove());
      markersRef.current = [];
      map.remove();
      mapRef.current = null;
    };
    // The map must be created once. Later prop changes are handled below.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    const map = mapRef.current;
    if (!map || !ready) return;

    markersRef.current.forEach((marker) => marker.remove());
    markersRef.current = [];

    const routeFeatures: Feature<LineString>[] = [];
    const bounds = new maplibregl.LngLatBounds();

    if (displayPath?.length) {
      routeFeatures.push(routeFeature(displayPath, "selected"));
      displayPath.forEach(([lat, lng]) => bounds.extend([lng, lat]));
    } else {
      trips.forEach((trip) => {
        if (trip.pickup_lat == null || trip.pickup_lng == null || trip.dropoff_lat == null || trip.dropoff_lng == null) {
          return;
        }
        const a: [number, number] = [trip.pickup_lat, trip.pickup_lng];
        const b: [number, number] = [trip.dropoff_lat, trip.dropoff_lng];
        const fallbackPath = softenRoute([a, b]);
        routeFeatures.push(routeFeature(fallbackPath, `trip-${trip.id}`));
        fallbackPath.forEach(([lat, lng]) => bounds.extend([lng, lat]));
      });
    }

    const source = map.getSource("routes") as GeoJSONSource | undefined;
    source?.setData({
      type: "FeatureCollection",
      features: routeFeatures,
    });

    trips.forEach((trip) => {
      if (trip.pickup_lat == null || trip.pickup_lng == null || trip.dropoff_lat == null || trip.dropoff_lng == null) return;
      addMarker({
        map,
        markers: markersRef.current,
        lngLat: [trip.pickup_lng, trip.pickup_lat],
        element: pointMarker("#2563eb"),
        popup: `<strong>${escapeHtml(trip.child_name ?? `Заказ #${trip.id}`)}</strong><br/>${escapeHtml(trip.pickup_text)} → ${escapeHtml(trip.dropoff_text)}<br/>Статус: ${escapeHtml(trip.status)}`,
      });
      addMarker({
        map,
        markers: markersRef.current,
        lngLat: [trip.dropoff_lng, trip.dropoff_lat],
        element: pointMarker("#f97316"),
        popup: `Назначение: ${escapeHtml(trip.dropoff_text)}`,
      });
    });

    driverPositions.forEach((driver) => {
      addMarker({
        map,
        markers: markersRef.current,
        lngLat: [driver.lng, driver.lat],
        element: emojiMarker("🚕"),
        popup: `Водитель · заказ #${driver.tripId}`,
      });
      bounds.extend([driver.lng, driver.lat]);
    });

    taxis.forEach((taxi) => {
      if (taxi.lat == null || taxi.lng == null) return;
      addMarker({
        map,
        markers: markersRef.current,
        lngLat: [taxi.lng, taxi.lat],
        element: taxiMarker(taxi.heading),
        popup: taxiPopup(taxi),
      });
      bounds.extend([taxi.lng, taxi.lat]);
    });

    if (!bounds.isEmpty()) {
      map.fitBounds(bounds as LngLatBoundsLike, {
        padding: 44,
        maxZoom: displayPath ? 15 : 13,
        duration: 700,
      });
    }
  }, [displayPath, driverPositions, ready, taxis, trips]);

  return (
    <div
      ref={containerRef}
      className="h-full w-full overflow-hidden rounded-2xl"
      aria-label="Карта поездок MapLibre"
    />
  );
}

function emptyRouteCollection(): FeatureCollection<LineString> {
  return { type: "FeatureCollection", features: [] };
}

function routeFeature(path: [number, number][], id: string): Feature<LineString> {
  return {
    type: "Feature",
    id,
    properties: {},
    geometry: {
      type: "LineString",
      coordinates: path.map(([lat, lng]) => [lng, lat]),
    },
  };
}

function addMarker({
  map,
  markers,
  lngLat,
  element,
  popup,
}: {
  map: maplibregl.Map;
  markers: Marker[];
  lngLat: [number, number];
  element: HTMLElement;
  popup: string;
}) {
  const marker = new maplibregl.Marker({ element })
    .setLngLat(lngLat)
    .setPopup(new maplibregl.Popup({ offset: 18 }).setHTML(popup))
    .addTo(map);
  markers.push(marker);
}

function pointMarker(color: string) {
  const el = document.createElement("div");
  el.style.width = "18px";
  el.style.height = "18px";
  el.style.borderRadius = "999px";
  el.style.background = color;
  el.style.border = "3px solid white";
  el.style.boxShadow = "0 0 0 1px rgba(0,0,0,.18), 0 4px 12px rgba(0,0,0,.2)";
  return el;
}

function emojiMarker(label: string) {
  const el = document.createElement("div");
  el.textContent = label;
  el.style.fontSize = "22px";
  el.style.lineHeight = "1";
  el.style.filter = "drop-shadow(0 2px 3px rgba(0,0,0,.3))";
  return el;
}

function taxiMarker(heading: number) {
  const el = document.createElement("div");
  el.className = "taxi-marker";
  el.innerHTML = `<div style="transform: rotate(${Math.round(heading)}deg); width:34px; height:34px; filter: drop-shadow(0 2px 3px rgba(0,0,0,.35))">
    <svg viewBox="0 0 24 40" width="34" height="34" style="display:block" xmlns="http://www.w3.org/2000/svg">
      <rect x="4" y="2" width="16" height="36" rx="6" fill="#FFCE00" stroke="#15161A" stroke-width="1.6"/>
      <rect x="6.2" y="8" width="11.6" height="6.5" rx="2" fill="#2A2C33"/>
      <rect x="6.2" y="26" width="11.6" height="5.5" rx="2" fill="#2A2C33"/>
      <rect x="9.4" y="17.4" width="5.2" height="5.2" fill="#15161A" opacity="0.85"/>
      <rect x="3" y="6" width="2.4" height="5" rx="1.2" fill="#15161A"/>
      <rect x="18.6" y="6" width="2.4" height="5" rx="1.2" fill="#15161A"/>
      <rect x="3" y="28" width="2.4" height="5" rx="1.2" fill="#15161A"/>
      <rect x="18.6" y="28" width="2.4" height="5" rx="1.2" fill="#15161A"/>
    </svg>
  </div>`;
  return el;
}

function taxiPopup(taxi: DriverLocation) {
  const vehicle = taxi.vehicle
    ? ` · ${escapeHtml(taxi.vehicle.make)} ${escapeHtml(taxi.vehicle.model)} · ${escapeHtml(taxi.vehicle.plate_number)}`
    : "";
  const photo = taxi.photo
    ? `<img src="${escapeHtml(taxi.photo)}" alt="${escapeHtml(taxi.full_name)}" style="width:44px;height:44px;border-radius:12px;object-fit:cover" />`
    : "";
  return `<div style="display:flex;gap:10px;align-items:center;min-width:200px">
      ${photo}
      <div>
        <div style="font-weight:700">${escapeHtml(taxi.full_name)}</div>
        <div style="font-size:12px;color:#8A8F98">★ ${Number(taxi.rating).toFixed(2)}${vehicle}</div>
      </div>
    </div>
    <a href="/drivers/${taxi.id}" style="display:block;margin-top:8px;text-align:center;background:#FFCE00;color:#15161A;font-weight:700;border-radius:10px;padding:6px 10px;text-decoration:none">
      Открыть профиль →
    </a>`;
}

function escapeHtml(value: string) {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}
