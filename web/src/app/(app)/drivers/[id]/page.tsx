"use client";

import { useState } from "react";
import type React from "react";
import { useParams, useRouter } from "next/navigation";
import useSWR from "swr";
import {
  ArrowLeft,
  Baby,
  BadgeCheck,
  Camera,
  Car,
  Phone,
  Mail,
  Star,
} from "lucide-react";
import { api, swrFetcher } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { DOC_STATUS, statusBadge } from "@/lib/status";
import BarChart from "@/components/BarChart";
import CarCard from "@/components/CarCard";
import StatCard from "@/components/StatCard";
import type { Driver, DriverStats } from "@/lib/types";

const fmt = (n: number | string) =>
  new Intl.NumberFormat("ru-RU").format(Math.round(Number(n))) + " ₸";
const d8 = (s: string) =>
  new Date(s).toLocaleDateString("ru-RU", { day: "2-digit", month: "short" });
const WEEKDAY = ["Вс", "Пн", "Вт", "Ср", "Чт", "Пт", "Сб"];

const PAYOUT_STATUS: Record<string, { label: string; cls: string }> = {
  pending: { label: "Ожидает", cls: "bg-amber-100 text-amber-700" },
  paid: { label: "Выплачено", cls: "bg-emerald-100 text-emerald-700" },
  cancelled: { label: "Отменено", cls: "bg-red-100 text-red-700" },
};

export default function DriverProfilePage() {
  const { id } = useParams<{ id: string }>();
  const router = useRouter();
  const { session } = useAuth();
  const canReview = session?.role === "admin" || session?.role === "operator";

  const { data: driver, mutate } = useSWR<Driver>(`/drivers/${id}/`, swrFetcher);

  async function review(action: "approve_docs" | "reject_docs") {
    await api.post(`/drivers/${id}/${action}/`);
    mutate();
  }
  const { data: stats } = useSWR<DriverStats>(`/drivers/${id}/stats/`, swrFetcher, {
    refreshInterval: 30000,
  });

  if (!driver) return <div className="text-muted">Загрузка…</div>;

  const doc = statusBadge(DOC_STATUS, driver.doc_status);
  const vehicle = driver.vehicles?.[0];
  const week = (stats?.income_by_day ?? []).map((p) => ({
    label: WEEKDAY[new Date(p.day + "T00:00:00").getDay()],
    value: p.amount,
    hint: `${d8(p.day)} · ${fmt(p.amount)}`,
  }));

  return (
    <div className="space-y-5">
      <div className="flex items-center gap-3">
        <button
          onClick={() => router.push("/drivers")}
          aria-label="Назад к списку водителей"
          className="h-9 w-9 grid place-items-center rounded-xl border border-line text-muted
                     hover:text-ink hover:bg-gray-50 cursor-pointer transition-colors duration-200"
        >
          <ArrowLeft className="h-4 w-4" />
        </button>
        <h1 className="text-2xl font-bold">Профиль водителя</h1>
      </div>

      <div className="grid xl:grid-cols-3 gap-4 items-start">
        {/* Left column: identity card */}
          <div className="card p-5 space-y-4">
          <div className="flex items-center gap-4">
            {driver.photo ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img
                src={driver.photo}
                alt={driver.full_name}
                className="h-24 w-24 rounded-2xl object-cover border border-line"
              />
            ) : (
              <div className="h-24 w-24 rounded-2xl bg-brand-soft grid place-items-center text-3xl font-bold text-brand-dark">
                {driver.full_name[0]}
              </div>
            )}
            <div>
              <div className="text-lg font-bold leading-tight">
                {driver.full_name}
              </div>
              <div className="mt-1 flex items-center gap-1.5 text-sm font-semibold">
                <Star className="h-4 w-4 text-brand-dark fill-brand" />
                {Number(driver.rating).toFixed(2)}
                <span className="text-muted font-normal">
                  · {stats?.reviews_count ?? 0} отзывов
                </span>
              </div>
              <span
                className={`badge mt-2 ${
                  driver.is_available
                    ? "bg-emerald-100 text-emerald-700"
                    : "bg-gray-100 text-gray-600"
                }`}
              >
                {driver.is_available ? "На линии" : "Не на линии"}
              </span>
            </div>
          </div>

          <div className="space-y-2 text-sm border-t border-line pt-4">
            <InfoRow icon={Phone} label="Телефон" value={driver.phone || "—"} />
            <InfoRow icon={Mail} label="Email" value={driver.email || "—"} />
            <InfoRow
              icon={Car}
              label="Машина"
              value={
                vehicle
                  ? `${vehicle.make} ${vehicle.model} · ${vehicle.plate_number}`
                  : "—"
              }
            />
            <InfoRow
              icon={Baby}
              label="Детское кресло"
              value={driver.has_child_seat ? "Есть" : "Нет"}
            />
            <InfoRow
              icon={BadgeCheck}
              label="Стаж"
              value={`${driver.experience_years} лет · ${stats?.completed_total ?? 0} поездок`}
            />
          </div>

          {canReview && <DriverEditCard driver={driver} onSaved={mutate} />}
        </div>

        {/* Right columns: money + charts */}
        <div className="xl:col-span-2 space-y-4">
          <div className="grid grid-cols-3 gap-4">
            <StatCard
              label="Сегодня заработано"
              value={fmt(stats?.earned_today ?? 0)}
            />
            <StatCard label="Поездок сегодня" value={stats?.trips_today ?? 0} />
            <StatCard
              label="Ожидается выплата"
              value={fmt(stats?.pending_amount ?? 0)}
              accent
            />
          </div>

          <div className="grid md:grid-cols-2 gap-4">
            <div className="card p-5">
              <div className="font-bold mb-3">История выплат</div>
              <div className="divide-y divide-line/70">
                {(stats?.payouts ?? []).map((p) => {
                  const s = statusBadge(PAYOUT_STATUS, p.status);
                  return (
                    <div key={p.id} className="flex items-center justify-between py-2.5">
                      <div>
                        <div className="text-[13px] font-medium">
                          {d8(p.period_start)} — {d8(p.period_end)}
                        </div>
                        <span className={`badge mt-1 ${s.cls}`}>{s.label}</span>
                      </div>
                      <div className="font-bold text-[15px]">
                        {fmt(p.total_amount)}
                      </div>
                    </div>
                  );
                })}
                {(stats?.payouts ?? []).length === 0 && (
                  <div className="text-sm text-muted py-2">Выплат пока нет</div>
                )}
              </div>
            </div>

            <div className="card p-5">
              <div className="flex items-baseline justify-between mb-3">
                <div className="font-bold">Доход за неделю</div>
                <div className="text-sm font-semibold text-muted">
                  {fmt(stats?.earned_week ?? 0)}
                </div>
              </div>
              <BarChart data={week} />
            </div>
          </div>

          {/* Vehicle */}
          {vehicle && <CarCard vehicle={vehicle} rating={driver.rating} />}

          {/* Documents & application review */}
          <div className="card p-5">
            <div className="flex flex-wrap items-center justify-between gap-2 mb-4">
              <div className="font-bold">
                Документы
                {driver.doc_status === "pending" && (
                  <span className="text-muted font-normal"> · заявка на проверке</span>
                )}
              </div>
              <div className="flex items-center gap-2">
                <span className={`badge ${doc.cls}`}>{doc.label}</span>
                {canReview && driver.doc_status !== "approved" && (
                  <button
                    className="btn-brand text-xs py-1"
                    onClick={() => review("approve_docs")}
                  >
                    Одобрить
                  </button>
                )}
                {canReview && driver.doc_status !== "rejected" && (
                  <button
                    className="btn-ghost text-xs py-1 text-red-600"
                    onClick={() => review("reject_docs")}
                  >
                    Отклонить
                  </button>
                )}
              </div>
            </div>

            <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
              <DocPhoto label="Вод. удостоверение" src={driver.license_photo} />
              <DocPhoto label="Удостоверение личности" src={driver.id_card_photo} />
              <DocPhoto label="Фото водителя" src={driver.photo} />
              <DocPhoto label="Фото автомобиля" src={vehicle?.photo} />
            </div>

            <div className="grid md:grid-cols-2 gap-2 text-sm mt-4">
              <DocRow label="Номер ВУ" value={driver.license_number || "—"} />
              <DocRow label="ИИН" value={driver.iin || "—"} />
              <DocRow
                label="Действительно до"
                value={
                  driver.license_expiry
                    ? new Date(driver.license_expiry).toLocaleDateString("ru-RU")
                    : "—"
                }
              />
              <DocRow
                label="Принят на работу"
                value={
                  driver.hired_at
                    ? new Date(driver.hired_at).toLocaleDateString("ru-RU")
                    : "—"
                }
              />
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

function InfoRow({
  icon: Icon,
  label,
  value,
}: {
  icon: typeof Phone;
  label: string;
  value: string;
}) {
  return (
    <div className="flex items-center gap-3 py-1">
      <Icon className="h-4 w-4 shrink-0 text-gray-400" strokeWidth={2.1} />
      <span className="text-muted w-32 shrink-0">{label}</span>
      <span className="font-medium min-w-0 truncate">{value}</span>
    </div>
  );
}

function DocPhoto({ label, src }: { label: string; src?: string | null }) {
  return (
    <div>
      <div className="text-xs text-muted mb-1">{label}</div>
      {src ? (
        <a href={src} target="_blank" rel="noreferrer" className="block">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            src={src}
            alt={label}
            className="w-full h-28 object-cover rounded-xl border border-line hover:opacity-90 transition-opacity cursor-pointer"
          />
        </a>
      ) : (
        <div className="h-28 grid place-items-center rounded-xl border border-dashed border-line text-muted text-xs">
          Нет фото
        </div>
      )}
    </div>
  );
}

function DocRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex justify-between gap-2 rounded-lg bg-gray-50 px-3 py-2">
      <span className="text-muted">{label}</span>
      <span className="font-semibold">{value}</span>
    </div>
  );
}

function DriverEditCard({
  driver,
  onSaved,
}: {
  driver: Driver;
  onSaved: () => void;
}) {
  const [fullName, setFullName] = useState(driver.full_name);
  const [phone, setPhone] = useState(driver.phone || "");
  const [iin, setIin] = useState(driver.iin || "");
  const [license, setLicense] = useState(driver.license_number || "");
  const [experience, setExperience] = useState(driver.experience_years);
  const [hasSeat, setHasSeat] = useState(Boolean(driver.has_child_seat));
  const [files, setFiles] = useState<Record<string, File | null>>({});
  const [saving, setSaving] = useState(false);

  async function save() {
    setSaving(true);
    try {
      const form = new FormData();
      form.set("full_name", fullName);
      form.set("phone", phone);
      form.set("iin", iin);
      form.set("license_number", license);
      form.set("experience_years", String(experience || 0));
      form.set("has_child_seat", hasSeat ? "true" : "false");
      Object.entries(files).forEach(([key, file]) => {
        if (file) form.set(key, file);
      });
      await api.upload(`/drivers/${driver.id}/`, form);
      onSaved();
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="border-t border-line pt-4 space-y-3">
      <div className="font-bold">Редактирование</div>
      <div className="grid grid-cols-2 gap-2">
        <input
          className="input"
          value={fullName}
          onChange={(e) => setFullName(e.target.value)}
          placeholder="ФИО"
        />
        <input
          className="input"
          value={phone}
          onChange={(e) => setPhone(e.target.value)}
          placeholder="Телефон"
        />
        <input
          className="input"
          value={iin}
          onChange={(e) => setIin(e.target.value)}
          placeholder="ИИН"
        />
        <input
          className="input"
          value={license}
          onChange={(e) => setLicense(e.target.value)}
          placeholder="Номер ВУ"
        />
        <input
          className="input"
          type="number"
          min={0}
          value={experience}
          onChange={(e) => setExperience(Number(e.target.value))}
          placeholder="Стаж"
        />
        <label className="flex items-center gap-2 rounded-xl border border-line px-3 py-2.5 text-sm font-semibold">
          <input
            type="checkbox"
            checked={hasSeat}
            onChange={(e) => setHasSeat(e.target.checked)}
          />
          Детское кресло
        </label>
      </div>
      <div className="grid grid-cols-1 gap-2">
        <UploadButton label="Фото водителя" name="photo" setFiles={setFiles} />
        <UploadButton label="Вод. удостоверение" name="license_photo" setFiles={setFiles} />
        <UploadButton label="Удостоверение личности" name="id_card_photo" setFiles={setFiles} />
      </div>
      <button className="btn-brand w-full" disabled={saving} onClick={save}>
        {saving ? "Сохранение..." : "Сохранить"}
      </button>
    </div>
  );
}

function UploadButton({
  label,
  name,
  setFiles,
}: {
  label: string;
  name: string;
  setFiles: React.Dispatch<React.SetStateAction<Record<string, File | null>>>;
}) {
  const [fileName, setFileName] = useState("");
  return (
    <label className="btn-ghost justify-start text-sm">
      <Camera className="h-4 w-4" />
      <span className="truncate">{fileName || label}</span>
      <input
        type="file"
        accept="image/*"
        className="hidden"
        onChange={(e) => {
          const file = e.target.files?.[0] ?? null;
          setFileName(file?.name ?? "");
          setFiles((prev) => ({ ...prev, [name]: file }));
        }}
      />
    </label>
  );
}
