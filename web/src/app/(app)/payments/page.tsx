"use client";

import useSWR from "swr";
import { swrFetcher } from "@/lib/api";
import { PAYMENT_STATUS, statusBadge } from "@/lib/status";
import type { Paginated, Payment } from "@/lib/types";

const fmt = (n: string | number) =>
  new Intl.NumberFormat("ru-RU").format(Number(n)) + " ₸";
const dt = (s: string | null) => (s ? new Date(s).toLocaleString("ru-RU") : "—");

const STATUS_MAP: Record<string, { label: string; cls: string }> = {
  success: { label: "Успешно", cls: "bg-emerald-100 text-emerald-700" },
  pending: { label: "В обработке", cls: "bg-amber-100 text-amber-700" },
  failed: { label: "Ошибка", cls: "bg-red-100 text-red-700" },
  refunded: { label: "Возврат", cls: "bg-orange-100 text-orange-700" },
};

export default function PaymentsPage() {
  const { data, isLoading } = useSWR<Paginated<Payment>>(
    "/payments/",
    swrFetcher,
    { refreshInterval: 15000 }
  );

  return (
    <div className="space-y-4">
      <h1 className="text-2xl font-bold">Платежи</h1>
      <div className="card overflow-hidden">
        <table className="data">
          <thead>
            <tr>
              <th>#</th>
              <th>Заказ</th>
              <th>Ребёнок</th>
              <th>Провайдер</th>
              <th>Сумма</th>
              <th>Статус</th>
              <th>Оплачен</th>
            </tr>
          </thead>
          <tbody>
            {isLoading && (
              <tr>
                <td colSpan={7} className="text-muted">Загрузка…</td>
              </tr>
            )}
            {data?.results.map((p) => {
              const s = STATUS_MAP[p.status] ?? statusBadge(PAYMENT_STATUS, p.status);
              return (
                <tr key={p.id}>
                  <td className="text-muted">{p.id}</td>
                  <td>#{p.trip}</td>
                  <td className="font-medium">{p.child_name}</td>
                  <td className="uppercase text-xs">{p.provider}</td>
                  <td className="font-semibold">{fmt(p.amount)}</td>
                  <td>
                    <span className={`badge ${s.cls}`}>{s.label}</span>
                  </td>
                  <td className="text-sm text-muted">{dt(p.paid_at)}</td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
    </div>
  );
}
