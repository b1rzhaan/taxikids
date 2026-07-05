"use client";

import { useMemo, useState } from "react";
import dynamic from "next/dynamic";
import Link from "next/link";
import useSWR from "swr";
import { ChevronRight, Star } from "lucide-react";
import { swrFetcher } from "@/lib/api";
import { ACTIVE_STATUSES } from "@/lib/status";
import StatCard from "@/components/StatCard";
import LineChart from "@/components/LineChart";
import Donut from "@/components/Donut";
import type {
  DashboardStats,
  DriverLocation,
  Paginated,
  Trip,
} from "@/lib/types";

const LiveMap = dynamic(() => import("@/components/LiveMap"), {
  ssr: false,
  loading: () => (
    <div className="h-full grid place-items-center text-muted">Карта…</div>
  ),
});

const fmt = (n: number | string) =>
  new Intl.NumberFormat("ru-RU").format(Math.round(Number(n))) + " ₸";
const fmtShort = (n: number) =>
  new Intl.NumberFormat("ru-RU", {
    notation: "compact",
    maximumFractionDigits: 1,
  }).format(n);
const dayLabel = (iso: string) =>
  new Date(iso + "T00:00:00").toLocaleDateString("ru-RU", {
    day: "numeric",
    month: "short",
  });

/** Week-over-week change (%) computed from a daily series. */
function wow(series: number[]): number | null {
  const last = series.slice(-7).reduce((a, b) => a + b, 0);
  const prev = series.slice(-14, -7).reduce((a, b) => a + b, 0);
  if (!prev) return null;
  return ((last - prev) / prev) * 100;
}

const PERIODS = [7, 14, 30] as const;

export default function DashboardPage() {
  const { data, error, isLoading } = useSWR<DashboardStats>(
    "/statistics/dashboard/",
    swrFetcher,
    { refreshInterval: 15000 }
  );
  const { data: tripsData } = useSWR<Paginated<Trip>>("/trips/", swrFetcher, {
    refreshInterval: 15000,
  });
  // Live taxi positions — poll fast so the cars glide around the map.
  const { data: taxis } = useSWR<DriverLocation[]>(
    "/drivers/locations/",
    swrFetcher,
    { refreshInterval: 5000 }
  );
  const [period, setPeriod] = useState<(typeof PERIODS)[number]>(14);

  const activeTrips = useMemo(
    () =>
      (tripsData?.results ?? []).filter((t) =>
        ACTIVE_STATUSES.includes(t.status)
      ),
    [tripsData]
  );

  if (isLoading) return <div className="text-muted">Загрузка…</div>;
  if (error || !data)
    return <div className="text-red-600">Не удалось загрузить статистику</div>;

  const series = data.trips_by_day ?? [];
  const revenue = Number(data.revenue.total);
  const expense = Number(data.driver_expense_total);
  const appPct = revenue ? Math.round(((revenue - expense) / revenue) * 100) : 0;
  const donePct = data.trips_total
    ? Math.round((data.trips_completed / data.trips_total) * 100)
    : 0;

  const trips30 = series.reduce((a, d) => a + d.trips, 0);
  const tripsDelta = wow(series.map((d) => d.trips));
  const revenueDelta = wow(series.map((d) => d.revenue));

  const chartData = series.slice(-period).map((d) => ({
    label: dayLabel(d.day),
    value: d.trips,
    hint: `${d.trips} поездок · ${fmt(d.revenue)}`,
  }));

  return (
    <div className="space-y-5">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold">Дашборд</h1>
        <div className="text-sm text-muted">
          Активных поездок: <b className="text-ink">{data.trips_active}</b>
        </div>
      </div>

      {/* KPI row */}
      <div className="grid grid-cols-2 xl:grid-cols-4 gap-4">
        <StatCard
          label="Заказы · 30 дней"
          value={trips30}
          delta={tripsDelta}
          sub={`всего за всё время: ${data.trips_total}`}
        />
        <StatCard
          label="Отменённые"
          value={data.trips_cancelled}
          sub="за всё время"
        />
        <StatCard
          label="Водители"
          value={data.drivers_count}
          sub="в автопарке"
        />
        <StatCard
          label="Выручка"
          value={fmt(revenue)}
          delta={revenueDelta}
          sub={`доход приложения: ${fmt(data.app_income_total)}`}
          accent
        />
      </div>

      {/* Chart + donuts */}
      <div className="grid xl:grid-cols-3 gap-4">
        <div className="card p-5 xl:col-span-2">
          <div className="flex items-center justify-between mb-4">
            <div className="font-bold">Поездки по дням</div>
            <div className="flex rounded-xl bg-gray-100 p-1">
              {PERIODS.map((p) => (
                <button
                  key={p}
                  onClick={() => setPeriod(p)}
                  className={`px-3 py-1 rounded-lg text-xs font-semibold cursor-pointer transition-colors duration-200 ${
                    period === p
                      ? "bg-white text-ink shadow-sm"
                      : "text-muted hover:text-ink"
                  }`}
                >
                  {p} дней
                </button>
              ))}
            </div>
          </div>
          <LineChart data={chartData} formatValue={(n) => `${n} поездок`} />
        </div>

        <div className="card p-5">
          <div className="font-bold mb-4">Показатели</div>
          <div className="flex items-start justify-around gap-2">
            <Donut percent={appPct} color="#FFCE00" label="Доход приложения">
              <div>
                <div className="text-lg font-extrabold">{appPct}%</div>
                <div className="text-[10px] text-muted">
                  {fmtShort(data.app_income_total)} ₸
                </div>
              </div>
            </Donut>
            <Donut percent={donePct} color="#15161A" label="Завершаемость">
              <div>
                <div className="text-lg font-extrabold">{donePct}%</div>
                <div className="text-[10px] text-muted">
                  {data.trips_completed} поездок
                </div>
              </div>
            </Donut>
          </div>
          <div className="mt-5 space-y-2 text-sm border-t border-line pt-4">
            <Row label="Выручка за месяц" value={fmt(data.revenue.month)} />
            <Row label="Выплаты водителям" value={fmt(expense)} />
            <Row label="К выплате" value={fmt(data.payouts_pending)} />
          </div>
        </div>
      </div>

      {/* Map + top drivers */}
      <div className="grid xl:grid-cols-3 gap-4">
        <div className="card overflow-hidden xl:col-span-2 h-[380px] relative">
          <LiveMap
            trips={activeTrips}
            driverPositions={[]}
            taxis={taxis ?? []}
            scrollZoom={false}
          />
          <Link
            href="/map"
            className="absolute top-3 right-3 z-[500] badge bg-white shadow-soft text-ink
                       hover:bg-brand-soft cursor-pointer transition-colors duration-200"
          >
            Открыть карту →
          </Link>
        </div>

        <div className="card p-5">
          <div className="flex items-center justify-between mb-3">
            <div className="font-bold">Лучшие водители</div>
            <Link
              href="/drivers"
              className="text-xs font-semibold text-muted hover:text-ink transition-colors duration-200"
            >
              Все →
            </Link>
          </div>
          <div className="divide-y divide-line/70">
            {(data.top_drivers ?? []).map((d) => (
              <Link
                key={d.id}
                href="/drivers"
                className="flex items-center gap-3 py-2.5 group cursor-pointer"
              >
                <div className="h-9 w-9 shrink-0 rounded-full bg-brand-soft grid place-items-center text-sm font-bold text-brand-dark">
                  {d.full_name[0]}
                </div>
                <div className="min-w-0 flex-1">
                  <div className="text-[13px] font-semibold truncate group-hover:text-brand-dark transition-colors duration-200">
                    {d.full_name}
                  </div>
                  <div className="text-[11px] text-muted">
                    {d.trips_count} поездок
                  </div>
                </div>
                <div className="flex items-center gap-1 text-[13px] font-semibold">
                  <Star className="h-3.5 w-3.5 text-brand-dark fill-brand" />
                  {Number(d.rating).toFixed(2)}
                </div>
                <ChevronRight className="h-4 w-4 text-gray-300 group-hover:text-ink transition-colors duration-200" />
              </Link>
            ))}
            {(data.top_drivers ?? []).length === 0 && (
              <div className="text-sm text-muted py-2">Пока нет водителей</div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}

function Row({ label, value }: { label: string; value: string | number }) {
  return (
    <div className="flex justify-between">
      <span className="text-muted">{label}</span>
      <span className="font-semibold">{value}</span>
    </div>
  );
}
