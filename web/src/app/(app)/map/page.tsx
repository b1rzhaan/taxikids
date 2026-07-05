"use client";

import { useEffect, useMemo, useState } from "react";
import dynamic from "next/dynamic";
import useSWR from "swr";
import { Circle, Clock, MapPin, Route } from "lucide-react";
import { swrFetcher } from "@/lib/api";
import {
  ACTIVE_STATUSES,
  TRIP_STATUS,
  PAYMENT_STATUS,
  statusBadge,
} from "@/lib/status";
import Stars from "@/components/Stars";
import type { DriverLocation, Paginated, Trip, TripDetail } from "@/lib/types";

const LiveMap = dynamic(() => import("@/components/LiveMap"), {
  ssr: false,
  loading: () => (
    <div className="h-full grid place-items-center text-muted">Карта…</div>
  ),
});

const fmt = (n: string | number) =>
  new Intl.NumberFormat("ru-RU").format(Number(n)) + " ₸";
const dt = (s: string) =>
  new Date(s).toLocaleString("ru-RU", {
    day: "numeric",
    month: "short",
    hour: "2-digit",
    minute: "2-digit",
  });
const km = (m?: number) => (m ? (m / 1000).toFixed(1) + " км" : "—");
const mins = (s?: number) => (s ? Math.max(1, Math.round(s / 60)) + " мин" : "—");

export default function MapPage() {
  const { data } = useSWR<Paginated<Trip>>("/trips/?page_size=100", swrFetcher, {
    refreshInterval: 15000,
  });
  const { data: taxis } = useSWR<DriverLocation[]>(
    "/drivers/locations/",
    swrFetcher,
    { refreshInterval: 5000 }
  );
  const trips = useMemo(() => data?.results ?? [], [data]);
  const [selectedId, setSelectedId] = useState<number | null>(null);

  // Pick the freshest trip by default once the history arrives.
  useEffect(() => {
    if (selectedId === null && trips.length > 0) setSelectedId(trips[0].id);
  }, [trips, selectedId]);

  const selected = trips.find((t) => t.id === selectedId) ?? null;
  const { data: detail } = useSWR<TripDetail>(
    selectedId ? `/trips/${selectedId}/` : null,
    swrFetcher
  );
  // Stable reference: otherwise FitPath re-fits the map on every poll render.
  const path = useMemo(
    () => (detail?.route_polyline ?? []) as [number, number][],
    [detail]
  );

  const activeCount = trips.filter((t) =>
    ACTIVE_STATUSES.includes(t.status)
  ).length;

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold">Карта поездок</h1>
          <div className="text-sm text-muted">
            История маршрутов · выберите поездку, чтобы увидеть траекторию
          </div>
        </div>
        <div className="text-sm text-muted">
          Активных сейчас: <b className="text-ink">{activeCount}</b>
        </div>
      </div>

      <div className="grid xl:grid-cols-[1fr_380px] gap-4 items-start">
        {/* Map + selected trip details */}
        <div className="space-y-4">
          <div className="card overflow-hidden h-[52vh]">
            <LiveMap
              trips={selected ? [selected] : []}
              driverPositions={[]}
              taxis={taxis ?? []}
              path={path}
              scrollZoom={false}
            />
          </div>

          {selected && (
            <div className="card p-5">
              <div className="flex flex-wrap items-center justify-between gap-2 mb-3">
                <div className="font-bold">
                  Заказ #{selected.id} · {selected.child_name}
                </div>
                <div className="flex items-center gap-2">
                  <span
                    className={`badge ${statusBadge(TRIP_STATUS, selected.status).cls}`}
                  >
                    {statusBadge(TRIP_STATUS, selected.status).label}
                  </span>
                  <span
                    className={`badge ${
                      statusBadge(PAYMENT_STATUS, selected.payment_status).cls
                    }`}
                  >
                    {statusBadge(PAYMENT_STATUS, selected.payment_status).label}
                  </span>
                </div>
              </div>

              <div className="grid md:grid-cols-2 gap-x-6 gap-y-2 text-sm">
                <div className="space-y-1.5">
                  <div className="flex items-center gap-2">
                    <Circle className="h-2.5 w-2.5 shrink-0 text-brand-dark fill-brand" />
                    {selected.pickup_text}
                  </div>
                  <div className="flex items-center gap-2">
                    <MapPin className="h-3.5 w-3.5 shrink-0 text-gray-400" />
                    {selected.dropoff_text}
                  </div>
                </div>
                <div className="space-y-1.5">
                  <div className="flex items-center gap-2 text-muted">
                    <Clock className="h-3.5 w-3.5" />
                    {dt(selected.scheduled_at)}
                  </div>
                  <div className="flex items-center gap-2 text-muted">
                    <Route className="h-3.5 w-3.5" />
                    {km(selected.route_distance_m)} · {mins(selected.route_duration_s)}
                  </div>
                </div>
              </div>

              <div className="flex flex-wrap items-center justify-between gap-2 mt-4 pt-3 border-t border-line text-sm">
                <div className="text-muted">
                  Водитель: <b className="text-ink">{selected.driver_name || "—"}</b>
                </div>
                <div className="flex items-center gap-4">
                  <Stars
                    value={selected.parent_rating}
                    comment={selected.rating_comment}
                    size={4}
                  />
                  <div className="text-lg font-extrabold">
                    {fmt(selected.price_amount)}
                  </div>
                </div>
              </div>
            </div>
          )}
        </div>

        {/* History list */}
        <div className="card p-3 max-h-[78vh] overflow-y-auto">
          <div className="px-2 pt-1 pb-2 font-bold">История поездок</div>
          <div className="space-y-1.5">
            {trips.map((t) => {
              const s = statusBadge(TRIP_STATUS, t.status);
              const isSel = t.id === selectedId;
              return (
                <button
                  key={t.id}
                  onClick={() => setSelectedId(t.id)}
                  className={`w-full text-left p-3 rounded-xl border cursor-pointer transition-colors duration-150 ${
                    isSel
                      ? "border-brand bg-brand-soft"
                      : "border-transparent hover:bg-gray-50"
                  }`}
                >
                  <div className="flex items-center justify-between gap-2">
                    <div className="text-[13px] font-semibold truncate">
                      {t.pickup_text} → {t.dropoff_text}
                    </div>
                    <span className="text-[13px] font-bold shrink-0">
                      {fmt(t.price_amount)}
                    </span>
                  </div>
                  <div className="mt-1 flex items-center justify-between gap-2">
                    <div className="text-[11px] text-muted">
                      {dt(t.scheduled_at)} · {km(t.route_distance_m)}
                    </div>
                    <div className="flex items-center gap-2">
                      <Stars value={t.parent_rating} size={3} />
                      <span className={`badge ${s.cls}`}>{s.label}</span>
                    </div>
                  </div>
                </button>
              );
            })}
            {trips.length === 0 && (
              <div className="text-sm text-muted px-2 py-3">
                Поездок пока нет
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
