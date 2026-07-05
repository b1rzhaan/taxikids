"use client";

import { useState } from "react";
import useSWR from "swr";
import { api, swrFetcher } from "@/lib/api";
import type { Paginated, Tariff } from "@/lib/types";

const FIELDS = [
  ["base_fare", "Посадка, ₸"],
  ["per_km", "За км, ₸"],
  ["per_min", "За минуту, ₸"],
  ["min_fare", "Мин. цена, ₸"],
] as const;

export default function TariffsPage() {
  const { data, isLoading, mutate } = useSWR<Paginated<Tariff>>(
    "/tariffs/",
    swrFetcher
  );

  return (
    <div className="space-y-4">
      <div>
        <h1 className="text-2xl font-bold">Тарифы</h1>
        <div className="text-sm text-muted">
          Правила расчёта цены поездки · доступно только администратору
        </div>
      </div>
      <div className="grid md:grid-cols-2 xl:grid-cols-3 gap-4">
        {isLoading && <div className="text-muted">Загрузка…</div>}
        {data?.results.map((t) => (
          <TariffCard key={t.id} tariff={t} onSaved={mutate} />
        ))}
      </div>
    </div>
  );
}

function TariffCard({ tariff, onSaved }: { tariff: Tariff; onSaved: () => void }) {
  const [values, setValues] = useState<Record<string, string>>({
    base_fare: tariff.base_fare,
    per_km: tariff.per_km,
    per_min: tariff.per_min,
    min_fare: tariff.min_fare,
  });
  const [busy, setBusy] = useState(false);
  const [ok, setOk] = useState(false);
  const [err, setErr] = useState("");

  const dirty = FIELDS.some(
    ([k]) => Number(values[k]) !== Number(tariff[k as keyof Tariff])
  );

  async function save() {
    setBusy(true);
    setErr("");
    setOk(false);
    try {
      await api.patch(`/tariffs/${tariff.id}/`, values);
      setOk(true);
      onSaved();
    } catch (e) {
      setErr((e as Error).message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="card p-5 space-y-3">
      <div className="flex items-center justify-between">
        <div className="font-bold">{tariff.name}</div>
        <span
          className={`badge ${
            tariff.is_active
              ? "bg-emerald-100 text-emerald-700"
              : "bg-gray-100 text-gray-600"
          }`}
        >
          {tariff.is_active ? "Активен" : "Выключен"}
        </span>
      </div>
      <div className="grid grid-cols-2 gap-3">
        {FIELDS.map(([key, label]) => (
          <div key={key}>
            <label className="text-xs text-muted">{label}</label>
            <input
              type="number"
              className="input mt-1"
              value={values[key]}
              onChange={(e) =>
                setValues((v) => ({ ...v, [key]: e.target.value }))
              }
            />
          </div>
        ))}
      </div>
      {err && <div className="text-sm text-red-600">{err}</div>}
      <button
        className="btn-brand w-full"
        disabled={!dirty || busy}
        onClick={save}
      >
        {busy ? "Сохраняю…" : ok && !dirty ? "Сохранено ✓" : "Сохранить"}
      </button>
    </div>
  );
}
