"use client";

import { useState } from "react";
import useSWR from "swr";
import { api, downloadFile, swrFetcher } from "@/lib/api";
import type { Paginated, Payout, Driver } from "@/lib/types";

const fmt = (n: string | number) =>
  new Intl.NumberFormat("ru-RU").format(Number(n)) + " ₸";

const PAYOUT: Record<string, { label: string; cls: string }> = {
  pending: { label: "Ожидает", cls: "bg-amber-100 text-amber-700" },
  paid: { label: "Выплачено", cls: "bg-emerald-100 text-emerald-700" },
  cancelled: { label: "Отменено", cls: "bg-red-100 text-red-700" },
};

export default function PayoutsPage() {
  const { data, isLoading, mutate } = useSWR<Paginated<Payout>>(
    "/payouts/",
    swrFetcher
  );
  const [open, setOpen] = useState(false);

  async function markPaid(id: number) {
    await api.post(`/payouts/${id}/mark_paid/`);
    mutate();
  }

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold">Выплаты водителям</h1>
        <button className="btn-brand" onClick={() => setOpen(true)}>
          + Создать выплату
        </button>
      </div>

      <div className="card overflow-hidden">
        <table className="data">
          <thead>
            <tr>
              <th>#</th>
              <th>Водитель</th>
              <th>Период</th>
              <th>Поездок</th>
              <th>Сумма</th>
              <th>Статус</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {isLoading && (
              <tr>
                <td colSpan={7} className="text-muted">Загрузка…</td>
              </tr>
            )}
            {data?.results.map((p) => {
              const s = PAYOUT[p.status] ?? PAYOUT.pending;
              return (
                <tr key={p.id}>
                  <td className="text-muted">{p.id}</td>
                  <td className="font-medium">{p.driver_name}</td>
                  <td className="text-sm">
                    {p.period_start} — {p.period_end}
                  </td>
                  <td>{p.items_count ?? "—"}</td>
                  <td className="font-semibold">{fmt(p.total_amount)}</td>
                  <td>
                    <span className={`badge ${s.cls}`}>{s.label}</span>
                  </td>
                  <td className="flex gap-2">
                    {p.status === "pending" && (
                      <button
                        className="btn-brand text-xs py-1"
                        onClick={() => markPaid(p.id)}
                      >
                        Выплатить
                      </button>
                    )}
                    <button
                      className="btn-ghost text-xs py-1"
                      onClick={() =>
                        downloadFile(
                          `/payouts/${p.id}/export/`,
                          `payout_${p.id}.csv`
                        )
                      }
                    >
                      CSV
                    </button>
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>

      {open && (
        <CreatePayout
          onClose={() => setOpen(false)}
          onDone={() => {
            setOpen(false);
            mutate();
          }}
        />
      )}
    </div>
  );
}

function CreatePayout({
  onClose,
  onDone,
}: {
  onClose: () => void;
  onDone: () => void;
}) {
  const { data } = useSWR<Paginated<Driver>>("/drivers/", swrFetcher);
  const today = new Date().toISOString().slice(0, 10);
  const monthAgo = new Date(Date.now() - 30 * 864e5).toISOString().slice(0, 10);
  const [driverId, setDriverId] = useState<number | "">("");
  const [start, setStart] = useState(monthAgo);
  const [end, setEnd] = useState(today);
  const [err, setErr] = useState("");
  const [busy, setBusy] = useState(false);

  async function create() {
    if (!driverId) return;
    setBusy(true);
    setErr("");
    try {
      await api.post("/payouts/", {
        driver_id: driverId,
        period_start: start,
        period_end: end,
      });
      onDone();
    } catch (e) {
      setErr((e as Error).message);
      setBusy(false);
    }
  }

  return (
    <div className="fixed inset-0 bg-black/30 grid place-items-center p-4 z-50">
      <div className="card p-6 w-full max-w-md space-y-3">
        <div className="text-lg font-bold">Создать выплату</div>
        <div>
          <label className="text-sm text-muted">Водитель</label>
          <select
            className="input mt-1"
            value={driverId}
            onChange={(e) => setDriverId(Number(e.target.value))}
          >
            <option value="">— выберите —</option>
            {data?.results.map((d) => (
              <option key={d.id} value={d.id}>
                {d.full_name}
              </option>
            ))}
          </select>
        </div>
        <div className="grid grid-cols-2 gap-3">
          <div>
            <label className="text-sm text-muted">С</label>
            <input
              type="date"
              className="input mt-1"
              value={start}
              onChange={(e) => setStart(e.target.value)}
            />
          </div>
          <div>
            <label className="text-sm text-muted">По</label>
            <input
              type="date"
              className="input mt-1"
              value={end}
              onChange={(e) => setEnd(e.target.value)}
            />
          </div>
        </div>
        {err && <div className="text-sm text-red-600">{err}</div>}
        <div className="flex gap-2 pt-2">
          <button className="btn-ghost flex-1" onClick={onClose}>
            Отмена
          </button>
          <button
            className="btn-brand flex-1"
            disabled={!driverId || busy}
            onClick={create}
          >
            {busy ? "…" : "Создать"}
          </button>
        </div>
      </div>
    </div>
  );
}
