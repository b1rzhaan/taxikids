"use client";

import { useMemo, useState } from "react";
import useSWR from "swr";
import { Camera, Search, UserRound } from "lucide-react";
import { api, swrFetcher } from "@/lib/api";
import type { Paginated, ParentProfile } from "@/lib/types";

export default function ParentsPage() {
  const { data, isLoading, mutate } = useSWR<Paginated<ParentProfile>>(
    "/auth/parents/?page_size=100",
    swrFetcher
  );
  const [q, setQ] = useState("");
  const [editing, setEditing] = useState<ParentProfile | null>(null);

  const rows = useMemo(() => {
    const needle = q.trim().toLowerCase();
    return (data?.results ?? []).filter((p) => {
      if (!needle) return true;
      return [p.full_name, p.phone, p.email, p.default_address]
        .filter(Boolean)
        .some((v) => String(v).toLowerCase().includes(needle));
    });
  }, [data, q]);

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="text-2xl font-bold">Родители</h1>
          <div className="text-sm text-muted">
            Клиенты, дети, контактные данные и фото профиля
          </div>
        </div>
        <label className="relative block">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-gray-400" />
          <input
            value={q}
            onChange={(e) => setQ(e.target.value)}
            placeholder="Имя, телефон, email..."
            className="input pl-9 w-72"
          />
        </label>
      </div>

      <div className="card overflow-x-auto">
        <table className="data min-w-[900px]">
          <thead>
            <tr>
              <th>Клиент</th>
              <th>Телефон</th>
              <th>Дети</th>
              <th>Адрес</th>
              <th>Создан</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {isLoading && (
              <tr>
                <td colSpan={6} className="text-muted">
                  Загрузка...
                </td>
              </tr>
            )}
            {!isLoading && rows.length === 0 && (
              <tr>
                <td colSpan={6} className="text-muted">
                  Клиентов пока нет
                </td>
              </tr>
            )}
            {rows.map((p) => (
              <tr key={p.id}>
                <td>
                  <div className="flex items-center gap-3">
                    {p.photo ? (
                      // eslint-disable-next-line @next/next/no-img-element
                      <img
                        src={p.photo}
                        alt={p.full_name}
                        className="h-10 w-10 rounded-full object-cover border border-line"
                      />
                    ) : (
                      <div className="h-10 w-10 rounded-full bg-brand-soft grid place-items-center text-sm font-bold text-brand-dark">
                        {(p.full_name[0] ?? "?").toUpperCase()}
                      </div>
                    )}
                    <div>
                      <div className="font-semibold">{p.full_name}</div>
                      <div className="text-xs text-muted">{p.email}</div>
                    </div>
                  </div>
                </td>
                <td>{p.phone || "—"}</td>
                <td>
                  <div className="flex flex-wrap gap-1.5">
                    {(p.children ?? []).map((child) => (
                      <span key={child.id} className="badge bg-gray-100 text-ink">
                        {child.full_name}
                      </span>
                    ))}
                    {(p.children ?? []).length === 0 && (
                      <span className="text-muted">—</span>
                    )}
                  </div>
                </td>
                <td className="max-w-56 truncate">{p.default_address || "—"}</td>
                <td className="text-muted">
                  {new Date(p.created_at).toLocaleDateString("ru-RU")}
                </td>
                <td>
                  <button className="btn-ghost text-xs py-1" onClick={() => setEditing(p)}>
                    Редактировать
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {editing && (
        <ParentEditor
          parent={editing}
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

function ParentEditor({
  parent,
  onClose,
  onSaved,
}: {
  parent: ParentProfile;
  onClose: () => void;
  onSaved: () => void;
}) {
  const [fullName, setFullName] = useState(parent.full_name);
  const [phone, setPhone] = useState(parent.phone ?? "");
  const [address, setAddress] = useState(parent.default_address ?? "");
  const [photo, setPhoto] = useState<File | null>(null);
  const [saving, setSaving] = useState(false);

  async function save() {
    setSaving(true);
    try {
      const form = new FormData();
      form.set("full_name", fullName);
      form.set("phone", phone);
      form.set("default_address", address);
      if (photo) form.set("photo", photo);
      await api.upload(`/auth/parents/${parent.id}/`, form);
      onSaved();
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="fixed inset-0 z-50 bg-black/30 grid place-items-center p-4">
      <div className="card w-full max-w-xl p-5 space-y-4">
        <div className="flex items-center justify-between">
          <div>
            <div className="font-bold text-lg">Редактировать клиента</div>
            <div className="text-sm text-muted">{parent.email}</div>
          </div>
          <button className="btn-ghost py-1.5" onClick={onClose}>
            Закрыть
          </button>
        </div>

        <div className="flex items-center gap-4">
          <div className="h-20 w-20 rounded-2xl bg-brand-soft grid place-items-center overflow-hidden">
            {parent.photo ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img src={parent.photo} alt={parent.full_name} className="h-full w-full object-cover" />
            ) : (
              <UserRound className="h-9 w-9 text-brand-dark" />
            )}
          </div>
          <label className="btn-ghost">
            <Camera className="h-4 w-4" />
            Заменить фото
            <input
              type="file"
              accept="image/*"
              className="hidden"
              onChange={(e) => setPhoto(e.target.files?.[0] ?? null)}
            />
          </label>
          {photo && <span className="text-sm text-muted">{photo.name}</span>}
        </div>

        <div className="grid md:grid-cols-2 gap-3">
          <label className="text-sm font-semibold">
            Имя
            <input className="input mt-1" value={fullName} onChange={(e) => setFullName(e.target.value)} />
          </label>
          <label className="text-sm font-semibold">
            Телефон
            <input className="input mt-1" value={phone} onChange={(e) => setPhone(e.target.value)} />
          </label>
          <label className="text-sm font-semibold md:col-span-2">
            Адрес по умолчанию
            <input className="input mt-1" value={address} onChange={(e) => setAddress(e.target.value)} />
          </label>
        </div>

        <div>
          <div className="font-semibold mb-2">Дети</div>
          <div className="flex flex-wrap gap-2">
            {(parent.children ?? []).map((child) => (
              <span key={child.id} className="badge bg-brand-soft text-ink">
                {child.full_name} · {child.school || "школа не указана"}
              </span>
            ))}
          </div>
        </div>

        <button className="btn-brand w-full" disabled={saving} onClick={save}>
          {saving ? "Сохранение..." : "Сохранить изменения"}
        </button>
      </div>
    </div>
  );
}
