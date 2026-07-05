"use client";

import { useEffect } from "react";
import {
  MapContainer,
  TileLayer,
  Marker,
  Popup,
  Polyline,
  useMap,
} from "react-leaflet";
import L from "leaflet";
import "leaflet/dist/leaflet.css";
import type { DriverLocation, Trip } from "@/lib/types";

/** Fits the viewport to the given trajectory whenever it changes. */
function FitPath({ path }: { path: [number, number][] }) {
  const map = useMap();
  useEffect(() => {
    if (path.length > 1) {
      map.fitBounds(L.latLngBounds(path.map(([a, b]) => L.latLng(a, b))), {
        padding: [36, 36],
      });
    }
  }, [path, map]);
  return null;
}

// Fix default marker icons (Next bundling breaks the default paths).
const icon = (color: string) =>
  L.divIcon({
    className: "",
    html: `<div style="background:${color};width:16px;height:16px;border-radius:50%;
           border:3px solid white;box-shadow:0 0 0 1px rgba(0,0,0,.2)"></div>`,
    iconSize: [16, 16],
    iconAnchor: [8, 8],
  });

const carIcon = L.divIcon({
  className: "",
  html: `<div style="font-size:22px;line-height:1">🚕</div>`,
  iconSize: [22, 22],
  iconAnchor: [11, 11],
});

// Top-view taxi (like ride-hailing apps), rotated to the driving direction.
const taxiIcon = (heading: number) =>
  L.divIcon({
    className: "taxi-marker",
    html: `<div style="transform: rotate(${Math.round(heading)}deg); width:34px; height:34px; filter: drop-shadow(0 2px 3px rgba(0,0,0,.35))">
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
    </div>`,
    iconSize: [34, 34],
    iconAnchor: [17, 17],
    popupAnchor: [0, -14],
  });

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
  return (
    <MapContainer
      center={center}
      zoom={12}
      style={{ height: "100%", width: "100%", borderRadius: "1rem" }}
      scrollWheelZoom={scrollZoom}
    >
      <TileLayer
        attribution="&copy; OpenStreetMap"
        url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
      />
      {trips.map((t) => {
        if (t.pickup_lat == null || t.dropoff_lat == null) return null;
        const a: [number, number] = [t.pickup_lat, t.pickup_lng!];
        const b: [number, number] = [t.dropoff_lat, t.dropoff_lng!];
        return (
          <div key={t.id}>
            <Marker position={a} icon={icon("#2563eb")}>
              <Popup>
                <b>{t.child_name}</b>
                <br />
                {t.pickup_text} → {t.dropoff_text}
                <br />
                Статус: {t.status}
              </Popup>
            </Marker>
            <Marker position={b} icon={icon("#f97316")}>
              <Popup>Назначение: {t.dropoff_text}</Popup>
            </Marker>
            <Polyline positions={[a, b]} color="#FFCE00" weight={4} />
          </div>
        );
      })}
      {driverPositions.map((d) => (
        <Marker key={`car-${d.tripId}`} position={[d.lat, d.lng]} icon={carIcon}>
          <Popup>Водитель · заказ #{d.tripId}</Popup>
        </Marker>
      ))}
      {taxis.map(
        (t) =>
          t.lat != null && (
            <Marker
              key={`taxi-${t.id}`}
              position={[t.lat, t.lng]}
              icon={taxiIcon(t.heading)}
            >
              <Popup>
                <div style={{ display: "flex", gap: 10, alignItems: "center", minWidth: 200 }}>
                  {t.photo && (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img
                      src={t.photo}
                      alt={t.full_name}
                      style={{ width: 44, height: 44, borderRadius: 12, objectFit: "cover" }}
                    />
                  )}
                  <div>
                    <div style={{ fontWeight: 700 }}>{t.full_name}</div>
                    <div style={{ fontSize: 12, color: "#8A8F98" }}>
                      ★ {Number(t.rating).toFixed(2)}
                      {t.vehicle &&
                        ` · ${t.vehicle.make} ${t.vehicle.model} · ${t.vehicle.plate_number}`}
                    </div>
                  </div>
                </div>
                <a
                  href={`/drivers/${t.id}`}
                  style={{
                    display: "block",
                    marginTop: 8,
                    textAlign: "center",
                    background: "#FFCE00",
                    color: "#15161A",
                    fontWeight: 700,
                    borderRadius: 10,
                    padding: "6px 10px",
                    textDecoration: "none",
                  }}
                >
                  Открыть профиль →
                </a>
              </Popup>
            </Marker>
          )
      )}
      {path && path.length > 1 && (
        <>
          <Polyline
            positions={path}
            color="#15161A"
            weight={7}
            opacity={0.25}
          />
          <Polyline positions={path} color="#F5B800" weight={4.5} />
          <FitPath path={path} />
        </>
      )}
    </MapContainer>
  );
}
