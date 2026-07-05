"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import useSWR from "swr";
import { Bell, Search } from "lucide-react";
import { swrFetcher } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import type { DashboardStats } from "@/lib/types";

export default function Topbar() {
  const router = useRouter();
  const { session } = useAuth();
  const [q, setQ] = useState("");
  const { data } = useSWR<DashboardStats>("/statistics/dashboard/", swrFetcher, {
    refreshInterval: 15000,
  });
  const active = data?.trips_active ?? 0;
  const initial = (session?.email?.[0] ?? "?").toUpperCase();

  return (
    <header className="sticky top-0 z-30 bg-white border-b border-line">
      <div className="flex items-center gap-4 h-16 px-6">
        <form
          className="flex-1 max-w-xl"
          onSubmit={(e) => {
            e.preventDefault();
            router.push(`/trips?q=${encodeURIComponent(q.trim())}`);
          }}
        >
          <label className="relative block">
            <Search className="absolute left-3.5 top-1/2 -translate-y-1/2 h-4 w-4 text-gray-400" />
            <input
              value={q}
              onChange={(e) => setQ(e.target.value)}
              placeholder="Поиск по заказам: ребёнок, адрес, водитель…"
              aria-label="Поиск по заказам"
              className="w-full rounded-xl border border-line bg-gray-50/70 pl-10 pr-4 py-2.5 text-sm
                         outline-none transition-colors focus:border-brand-dark focus:ring-2 focus:ring-brand/25 focus:bg-white"
            />
          </label>
        </form>

        <div className="ml-auto flex items-center gap-3">
          <button
            aria-label={`Активные поездки: ${active}`}
            title="Активные поездки — открыть карту"
            onClick={() => router.push("/map")}
            className="relative h-10 w-10 grid place-items-center rounded-xl border border-line
                       text-muted hover:text-ink hover:bg-gray-50 cursor-pointer transition-colors duration-200"
          >
            <Bell className="h-[18px] w-[18px]" strokeWidth={2.1} />
            {active > 0 && (
              <span className="absolute -top-1.5 -right-1.5 min-w-5 h-5 px-1 rounded-full bg-brand
                               text-ink text-[11px] font-bold grid place-items-center border-2 border-white">
                {active}
              </span>
            )}
          </button>

          <div className="h-8 w-px bg-line" />

          <div className="flex items-center gap-2.5">
            <div className="h-10 w-10 rounded-full bg-brand-soft grid place-items-center text-sm font-bold text-brand-dark">
              {initial}
            </div>
            <div className="hidden md:block leading-tight">
              <div className="text-[13px] font-semibold">{session?.email}</div>
              <div className="text-[11px] uppercase tracking-wide text-muted">
                {session?.role}
              </div>
            </div>
          </div>
        </div>
      </div>
    </header>
  );
}
