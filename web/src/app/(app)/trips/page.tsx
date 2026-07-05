"use client";

import { Suspense, useMemo, useState } from "react";
import { useSearchParams } from "next/navigation";
import useSWR from "swr";
import { Banknote, CreditCard, Circle, MapPin, Search, Star } from "lucide-react";
import { api, swrFetcher } from "@/lib/api";
import { TRIP_STATUS, PAYMENT_STATUS, statusBadge } from "@/lib/status";
import type { Paginated, Trip, Driver } from "@/lib/types";

const fmt = (n: string | number) =>
  new Intl.NumberFormat("ru-RU").format(Number(n)) + " ₸";
const dateOf = (s: string) =>
  new Date(s).toLocaleDateString("ru-RU", { day: "numeric", month: "short", year: "numeric" });
const timeOf = (s: string) =>
  new Date(s).toLocaleTimeString("ru-RU", { hour: "2-digit", minute: "2-digit" });
const km = (m?: number) => (m ? (m / 1000).toFixed(1) + " км" : null);
const mins = (s?: number) => (s ? Math.max(1, Math.round(s / 60)) + " мин" : null);

export default function TripsPage() {
  return (
    <Suspense fallback={<div className="text-muted">Загрузка…</div>}>
      <TripsContent />
    </Suspense>
  );
}

function TripsContent() {
  const params = useSearchParams();
  const [q, setQ] = useState(params.get("q") ?? "");
  const [status, setStatus] = useState("all");
  // Status is filtered server-side so it covers the whole history.
  const { data, isLoading, mutate } = useSWR<Paginated<Trip>>(
    `/trips/?page_size=100${status !== "all" ? `&status=${status}` : ""}`,
    swrFetcher,
    { refreshInterval: 10000 }
  );
  const [assignFor, setAssignFor] = useState<Trip | null>(null);

  const rows = useMemo(() => {
    const needle = q.trim().toLowerCase();
    return (data?.results ?? []).filter((t) => {
      if (!needle) return true;
      return [t.child_name, t.driver_name, t.pickup_text, t.dropoff_text, `#${t.id}`]
        .filter(Boolean)
        .some((v) => String(v).toLowerCase().includes(needle));
    });
  }, [data, q]);

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-center gap-3 justify-between">
        <div>
          <h1 className="text-2xl font-bold">Заказы</h1>
          <div className="text-sm text-muted">
            История поездок · найдено: {rows.length}
          </div>
        </div>
        <div className="flex items-center gap-2">
          <label className="relative block">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-gray-400" />
            <input
              value={q}
              onChange={(e) => setQ(e.target.value)}
              placeholder="Ребёнок, адрес, водитель…"
              aria-label="Поиск по истории поездок"
              className="input pl-9 w-64"
            />
          </label>
          <select
            value={status}
            onChange={(e) => setStatus(e.target.value)}
            aria-label="Фильтр по статусу"
            className="input w-44 cursor-pointer"
          >
            <option value="all">Все статусы</option>
            {Object.entries(TRIP_STATUS).map(([key, v]) => (
              <option key={key} value={key}>
                {v.label}
              </option>
            ))}
          </select>
        </div>
      </div>

      <div className="card overflow-x-auto">
        <table className="data min-w-[980px]">
          <thead>
            <tr>
              <th>#</th>
              <th>Ребёнок</th>
              <th>Маршрут</th>
              <th>Время</th>
              <th>Водитель</th>
              <th>Оплата</th>
              <th>Оценка</th>
              <th>Статус</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {isLoading && (
              <tr>
                <td colSpan={9} className="text-muted">Загрузка…</td>
              </tr>
            )}
            {rows.map((t) => {
              const s = statusBadge(TRIP_STATUS, t.status);
              const p = statusBadge(PAYMENT_STATUS, t.payment_status);
              const meta = [km(t.route_distance_m), mins(t.route_duration_s)]
                .filter(Boolean)
                .join(" · ");
              return (
                <tr key={t.id}>
                  <td className="text-muted">{t.id}</td>
                  <td className="font-medium whitespace-nowrap">{t.child_name}</td>
                  <td className="min-w-56">
                    <div className="flex items-center gap-1.5 text-[13px]">
                      <Circle className="h-2.5 w-2.5 shrink-0 text-brand-dark fill-brand" />
                      <span className="truncate max-w-56">{t.pickup_text}</span>
                    </div>
                    <div className="flex items-center gap-1.5 text-[13px] mt-0.5">
                      <MapPin className="h-3 w-3 shrink-0 text-gray-400" />
                      <span className="truncate max-w-56">{t.dropoff_text}</span>
                    </div>
                    {meta && <div className="text-[11px] text-muted mt-0.5 pl-4">{meta}</div>}
                  </td>
                  <td className="whitespace-nowrap">
                    <div className="text-[13px] font-medium">{dateOf(t.scheduled_at)}</div>
                    <div className="text-[11px] text-muted">{timeOf(t.scheduled_at)}</div>
                  </td>
                  <td className="text-sm whitespace-nowrap">{t.driver_name || "—"}</td>
                  <td className="whitespace-nowrap">
                    <div className="font-semibold text-[13px] flex items-center gap-1.5">
                      {t.payment_method === "cash" ? (
                        <Banknote className="h-3.5 w-3.5 text-emerald-600" />
                      ) : (
                        <CreditCard className="h-3.5 w-3.5 text-gray-400" />
                      )}
                      {fmt(t.price_amount)}
                    </div>
                    <span className={`badge mt-0.5 ${p.cls}`}>{p.label}</span>
                  </td>
                  <td>
                    <Stars value={t.parent_rating ?? null} comment={t.rating_comment} />
                  </td>
                  <td>
                    <span className={`badge whitespace-nowrap ${s.cls}`}>{s.label}</span>
                  </td>
                  <td>
                    {t.status === "paid" && (
                      <button
                        className="btn-brand text-xs py-1"
                        onClick={() => setAssignFor(t)}
                      >
                        Назначить
                      </button>
                    )}
                  </td>
                </tr>
              );
            })}
            {!isLoading && rows.length === 0 && (
              <tr>
                <td colSpan={9} className="text-muted">Ничего не найдено</td>
              </tr>
            )}
          </tbody>
        </table>
      </div>

      {assignFor && (
        <AssignModal
          trip={assignFor}
          onClose={() => setAssignFor(null)}
          onDone={() => {
            setAssignFor(null);
            mutate();
          }}
        />
      )}
    </div>
  );
}

function Stars({ value, comment }: { value: number | null; comment?: string }) {
  if (!value) return <span className="text-muted text-sm">—</span>;
  return (
    <div
      className="flex items-center gap-0.5"
      title={comment || `Оценка: ${value} из 5`}
      aria-label={`Оценка ${value} из 5`}
    >
      {[1, 2, 3, 4, 5].map((i) => (
        <Star
          key={i}
          className={`h-3.5 w-3.5 ${
            i <= value ? "text-brand-dark fill-brand" : "text-gray-200 fill-gray-100"
          }`}
        />
      ))}
    </div>
  );
}

function AssignModal({
  trip,
  onClose,
  onDone,
}: {
  trip: Trip;
  onClose: () => void;
  onDone: () => void;
}) {
  const { data } = useSWR<Paginated<Driver>>(
    "/drivers/?doc_status=approved&is_available=true",
    swrFetcher
  );
  const [driverId, setDriverId] = useState<number | null>(null);
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState("");

  async function assign() {
    if (!driverId) return;
    setBusy(true);
    setErr("");
    try {
      await api.post(`/trips/${trip.id}/assign/`, { driver_id: driverId });
      onDone();
    } catch (e) {
      setErr((e as Error).message);
      setBusy(false);
    }
  }

  return (
    <div className="fixed inset-0 bg-black/30 grid place-items-center p-4 z-50">
      <div className="card p-6 w-full max-w-md">
        <div className="text-lg font-bold mb-1">Назначить водителя</div>
        <div className="text-sm text-muted mb-4">
          Заказ #{trip.id} · {trip.child_name}
        </div>
        <div className="space-y-2 max-h-72 overflow-auto">
          {data?.results.map((d) => (
            <label
              key={d.id}
              className={`flex items-center gap-3 p-3 rounded-xl border cursor-pointer ${
                driverId === d.id ? "border-brand bg-brand-soft" : "border-gray-100"
              }`}
            >
              <input
                type="radio"
                name="driver"
                checked={driverId === d.id}
                onChange={() => setDriverId(d.id)}
              />
              <div>
                <div className="font-medium">{d.full_name}</div>
                <div className="text-xs text-muted flex items-center gap-1">
                  <Star className="h-3 w-3 text-brand-dark fill-brand" />
                  {d.rating} · стаж {d.experience_years} л ·{" "}
                  {d.vehicles?.[0]?.plate_number || "без машины"}
                </div>
              </div>
            </label>
          ))}
          {data && data.results.length === 0 && (
            <div className="text-sm text-muted">Нет доступных водителей</div>
          )}
        </div>
        {err && <div className="text-sm text-red-600 mt-2">{err}</div>}
        <div className="flex gap-2 mt-4">
          <button className="btn-ghost flex-1" onClick={onClose}>
            Отмена
          </button>
          <button
            className="btn-brand flex-1"
            disabled={!driverId || busy}
            onClick={assign}
          >
            {busy ? "…" : "Назначить"}
          </button>
        </div>
      </div>
    </div>
  );
}
