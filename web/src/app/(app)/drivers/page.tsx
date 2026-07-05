"use client";

import { useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import useSWR from "swr";
import { Star } from "lucide-react";
import { api, swrFetcher } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { DOC_STATUS } from "@/lib/status";
import type { Paginated, Driver } from "@/lib/types";

type Filter = "all" | "pending" | "approved";

export default function DriversPage() {
  const router = useRouter();
  const { session } = useAuth();
  const canReview = session?.role === "admin" || session?.role === "operator";
  const [filter, setFilter] = useState<Filter>("all");
  const { data, isLoading, mutate } = useSWR<Paginated<Driver>>(
    "/drivers/?page_size=100",
    swrFetcher
  );

  async function approve(id: number) {
    await api.post(`/drivers/${id}/approve_docs/`);
    mutate();
  }

  const all = useMemo(() => data?.results ?? [], [data]);
  const pendingCount = all.filter((d) => d.doc_status === "pending").length;
  const rows = all.filter((d) =>
    filter === "all"
      ? true
      : filter === "pending"
        ? d.doc_status !== "approved"
        : d.doc_status === "approved"
  );

  const tabs: { key: Filter; label: string; badge?: number }[] = [
    { key: "all", label: "Все" },
    { key: "pending", label: "На проверке", badge: pendingCount },
    { key: "approved", label: "Одобрены" },
  ];

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="text-2xl font-bold">Водители</h1>
          <div className="text-sm text-muted">
            Нажмите на водителя, чтобы открыть профиль и проверить документы
          </div>
        </div>
        <div className="flex rounded-xl bg-gray-100 p-1">
          {tabs.map((t) => (
            <button
              key={t.key}
              onClick={() => setFilter(t.key)}
              className={`px-3 py-1.5 rounded-lg text-sm font-semibold cursor-pointer transition-colors duration-200 flex items-center gap-1.5 ${
                filter === t.key
                  ? "bg-white text-ink shadow-sm"
                  : "text-muted hover:text-ink"
              }`}
            >
              {t.label}
              {t.badge ? (
                <span className="badge bg-red-100 text-red-600 px-1.5 py-0">
                  {t.badge}
                </span>
              ) : null}
            </button>
          ))}
        </div>
      </div>

      <div className="card overflow-hidden">
        <table className="data">
          <thead>
            <tr>
              <th>Водитель</th>
              <th>Телефон</th>
              <th>Рейтинг</th>
              <th>Стаж</th>
              <th>Машина</th>
              <th>Документы</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {isLoading && (
              <tr>
                <td colSpan={7} className="text-muted">Загрузка…</td>
              </tr>
            )}
            {!isLoading && rows.length === 0 && (
              <tr>
                <td colSpan={7} className="text-muted">Нет водителей</td>
              </tr>
            )}
            {rows.map((d) => {
              const doc = DOC_STATUS[d.doc_status] ?? DOC_STATUS.pending;
              return (
                <tr
                  key={d.id}
                  className="cursor-pointer"
                  onClick={() => router.push(`/drivers/${d.id}`)}
                >
                  <td>
                    <div className="flex items-center gap-3">
                      {d.photo ? (
                        // eslint-disable-next-line @next/next/no-img-element
                        <img
                          src={d.photo}
                          alt={d.full_name}
                          className="h-9 w-9 rounded-full object-cover border border-line"
                        />
                      ) : (
                        <div className="h-9 w-9 rounded-full bg-brand-soft grid place-items-center text-sm font-bold text-brand-dark">
                          {(d.full_name[0] ?? "?").toUpperCase()}
                        </div>
                      )}
                      <span className="font-medium">
                        {d.full_name || "Без имени"}
                      </span>
                    </div>
                  </td>
                  <td className="text-sm">{d.phone || "—"}</td>
                  <td>
                    <div className="flex items-center gap-1.5 font-semibold text-[13px]">
                      <Star className="h-3.5 w-3.5 text-brand-dark fill-brand" />
                      {Number(d.rating).toFixed(2)}
                    </div>
                  </td>
                  <td>{d.experience_years} л</td>
                  <td className="text-sm">
                    {d.vehicles?.[0]
                      ? `${d.vehicles[0].make} ${d.vehicles[0].model} · ${d.vehicles[0].plate_number}`
                      : "—"}
                  </td>
                  <td>
                    <span className={`badge ${doc.cls}`}>{doc.label}</span>
                  </td>
                  <td onClick={(e) => e.stopPropagation()}>
                    {canReview && d.doc_status !== "approved" && (
                      <button
                        className="btn-brand text-xs py-1"
                        onClick={() => approve(d.id)}
                      >
                        Одобрить
                      </button>
                    )}
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
    </div>
  );
}
