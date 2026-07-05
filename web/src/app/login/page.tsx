"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { login } from "@/lib/api";
import { useAuth, CABINET_ROLES } from "@/lib/auth";
import { homeFor } from "@/lib/roles";

const DEMO = [
  ["Админ", "admin@kids.kz", "admin12345"],
  ["Оператор", "operator@kids.kz", "operator12345"],
  ["Бухгалтер", "accountant@kids.kz", "accountant12345"],
];

export default function LoginPage() {
  const router = useRouter();
  const { signIn } = useAuth();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setError("");
    setLoading(true);
    try {
      const s = await login(email, password);
      if (!CABINET_ROLES.includes(s.role)) {
        setError("Этот кабинет только для оператора, админа и бухгалтера.");
        setLoading(false);
        return;
      }
      signIn(s);
      router.replace(homeFor(s.role));
    } catch {
      setError("Неверный логин или пароль");
      setLoading(false);
    }
  }

  return (
    <div className="min-h-screen flex items-center justify-center p-4">
      <div className="w-full max-w-md">
        <div className="flex items-center gap-3 mb-6 justify-center">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            src="/logo.png"
            alt="Детское такси"
            className="h-14 w-14 object-contain"
          />
          <div>
            <div className="text-xl font-bold">Детское такси</div>
            <div className="text-sm text-muted">Кабинет управления</div>
          </div>
        </div>

        <form onSubmit={submit} className="card p-6 space-y-4">
          <div>
            <label className="text-sm text-muted">Email</label>
            <input
              className="input mt-1"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              placeholder="operator@kids.kz"
              autoFocus
            />
          </div>
          <div>
            <label className="text-sm text-muted">Пароль</label>
            <input
              className="input mt-1"
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="••••••••"
            />
          </div>
          {error && <div className="text-sm text-red-600">{error}</div>}
          <button className="btn-brand w-full" disabled={loading}>
            {loading ? "Вход…" : "Войти"}
          </button>
        </form>

        <div className="mt-4 text-center text-xs text-muted">
          Демо-доступы (клик подставит):
          <div className="mt-2 flex flex-wrap gap-2 justify-center">
            {DEMO.map(([label, e, p]) => (
              <button
                key={e}
                onClick={() => {
                  setEmail(e);
                  setPassword(p);
                }}
                className="badge bg-brand-soft hover:bg-brand"
              >
                {label}
              </button>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
