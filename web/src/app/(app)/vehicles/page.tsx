"use client";

import { useMemo, useState } from "react";
import useSWR from "swr";
import { Camera, Search } from "lucide-react";
import { api, swrFetcher } from "@/lib/api";
import type { Paginated, Vehicle } from "@/lib/types";

export default function VehiclesPage() {
  const { data, isLoading, mutate } = useSWR<Paginated<Vehicle>>(
    "/vehicles/?page_size=100",
    swrFetcher
  );
  const [q, setQ] = useState("");
  const [editing, setEditing] = useState<Vehicle | null>(null);
  const rows = useMemo(() => {
    const needle = q.trim().toLowerCase();
    return (data?.results ?? []).filter((v) => {
      if (!needle) return true;
      return [v.make, v.model, v.plate_number, v.color, v.tech_passport]
        .filter(Boolean)
        .some((value) => String(value).toLowerCase().includes(needle));
    });
  }, [data, q]);

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="text-2xl font-bold">Автомобили</h1>
          <div className="text-sm text-muted">
            Автопарк, техпаспорт, фото и техническое состояние
          </div>
        </div>
        <label className="relative block">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-gray-400" />
          <input
            className="input pl-9 w-72"
            value={q}
            onChange={(e) => setQ(e.target.value)}
            placeholder="Марка, номер, техпаспорт..."
          />
        </label>
      </div>

      <div className="grid md:grid-cols-2 xl:grid-cols-3 gap-4">
        {isLoading && <div className="text-muted">Загрузка...</div>}
        {!isLoading && rows.length === 0 && (
          <div className="text-muted">Автомобилей пока нет</div>
        )}
        {rows.map((v) => (
          <button
            key={v.id}
            onClick={() => setEditing(v)}
            className="card p-4 text-left hover:shadow-lg transition-shadow"
          >
            <div className="flex gap-4">
              {v.photo ? (
                // eslint-disable-next-line @next/next/no-img-element
                <img
                  src={v.photo}
                  alt={`${v.make} ${v.model}`}
                  className="h-20 w-24 rounded-2xl object-cover border border-line"
                />
              ) : (
                <div className="h-20 w-24 rounded-2xl bg-brand-soft grid place-items-center font-bold">
                  TAXI
                </div>
              )}
              <div className="min-w-0 flex-1">
                <div className="font-bold truncate">
                  {v.make} {v.model}
                </div>
                <div className="mt-1 inline-flex rounded-lg bg-gray-100 px-2 py-1 text-xs font-bold">
                  {v.plate_number}
                </div>
                <div className="text-sm text-muted mt-2">
                  {v.color || "цвет не указан"} · {v.seats ?? 4} мест
                </div>
                <span
                  className={`badge mt-2 ${
                    v.is_active
                      ? "bg-emerald-100 text-emerald-700"
                      : "bg-gray-100 text-gray-600"
                  }`}
                >
                  {v.is_active ? "Активен" : "Не активен"}
                </span>
              </div>
            </div>
          </button>
        ))}
      </div>

      {editing && (
        <VehicleEditor
          vehicle={editing}
          onClose={() => setEditing(null)}
          onSaved={() => {
            setEditing(null);
            mutate();
          }}
        />
      )}
    </div>
  );
}

function VehicleEditor({
  vehicle,
  onClose,
  onSaved,
}: {
  vehicle: Vehicle;
  onClose: () => void;
  onSaved: () => void;
}) {
  const [make, setMake] = useState(vehicle.make);
  const [model, setModel] = useState(vehicle.model);
  const [plate, setPlate] = useState(vehicle.plate_number);
  const [color, setColor] = useState(vehicle.color ?? "");
  const [seats, setSeats] = useState(vehicle.seats ?? 4);
  const [year, setYear] = useState(vehicle.year ?? "");
  const [mileage, setMileage] = useState(vehicle.mileage_km ?? "");
  const [passport, setPassport] = useState(vehicle.tech_passport ?? "");
  const [active, setActive] = useState(Boolean(vehicle.is_active));
  const [photo, setPhoto] = useState<File | null>(null);
  const [saving, setSaving] = useState(false);

  async function save() {
    setSaving(true);
    try {
      const form = new FormData();
      form.set("make", make);
      form.set("model", model);
      form.set("plate_number", plate);
      form.set("color", color);
      form.set("seats", String(seats || 4));
      if (year) form.set("year", String(year));
      if (mileage) form.set("mileage_km", String(mileage));
      form.set("tech_passport", passport);
      form.set("is_active", active ? "true" : "false");
      if (photo) form.set("photo", photo);
      await api.upload(`/vehicles/${vehicle.id}/`, form);
      onSaved();
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="fixed inset-0 z-50 bg-black/30 grid place-items-center p-4">
      <div className="card w-full max-w-2xl p-5 space-y-4">
        <div className="flex items-center justify-between">
          <div>
            <div className="font-bold text-lg">Редактировать автомобиль</div>
            <div className="text-sm text-muted">{vehicle.plate_number}</div>
          </div>
          <button className="btn-ghost py-1.5" onClick={onClose}>
            Закрыть
          </button>
        </div>
        <div className="grid md:grid-cols-2 gap-3">
          <input className="input" value={make} onChange={(e) => setMake(e.target.value)} placeholder="Марка" />
          <input className="input" value={model} onChange={(e) => setModel(e.target.value)} placeholder="Модель" />
          <input className="input" value={plate} onChange={(e) => setPlate(e.target.value)} placeholder="Госномер" />
          <input className="input" value={color} onChange={(e) => setColor(e.target.value)} placeholder="Цвет" />
          <input className="input" type="number" value={seats} onChange={(e) => setSeats(Number(e.target.value))} placeholder="Места" />
          <input className="input" type="number" value={year} onChange={(e) => setYear(e.target.value)} placeholder="Год" />
          <input className="input" type="number" value={mileage} onChange={(e) => setMileage(e.target.value)} placeholder="Пробег" />
          <input className="input" value={passport} onChange={(e) => setPassport(e.target.value)} placeholder="Техпаспорт" />
        </div>
        <label className="flex items-center gap-2 text-sm font-semibold">
          <input type="checkbox" checked={active} onChange={(e) => setActive(e.target.checked)} />
          Автомобиль активен
        </label>
        <label className="btn-ghost justify-start">
          <Camera className="h-4 w-4" />
          {photo?.name || "Заменить фото автомобиля"}
          <input type="file" accept="image/*" className="hidden" onChange={(e) => setPhoto(e.target.files?.[0] ?? null)} />
        </label>
        <button className="btn-brand w-full" disabled={saving} onClick={save}>
          {saving ? "Сохранение..." : "Сохранить автомобиль"}
        </button>
      </div>
    </div>
  );
}
