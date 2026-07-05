import type { Session } from "./types";

const API_BASE =
  process.env.NEXT_PUBLIC_API_BASE || "http://localhost:8000/api";
const STORAGE_KEY = "kt_session";

export function getSession(): Session | null {
  if (typeof window === "undefined") return null;
  const raw = localStorage.getItem(STORAGE_KEY);
  return raw ? (JSON.parse(raw) as Session) : null;
}

export function setSession(s: Session | null) {
  if (typeof window === "undefined") return;
  if (s) localStorage.setItem(STORAGE_KEY, JSON.stringify(s));
  else localStorage.removeItem(STORAGE_KEY);
}

export class ApiError extends Error {
  status: number;
  data: unknown;
  constructor(status: number, message: string, data: unknown) {
    super(message);
    this.status = status;
    this.data = data;
  }
}

async function request<T>(
  path: string,
  options: RequestInit = {},
  retry = true
): Promise<T> {
  const session = getSession();
  const headers: Record<string, string> = {
    "Content-Type": "application/json",
    ...(options.headers as Record<string, string>),
  };
  if (session?.access) headers.Authorization = `Bearer ${session.access}`;

  const res = await fetch(`${API_BASE}${path}`, { ...options, headers });

  // Transparent token refresh on 401.
  if (res.status === 401 && retry && session?.refresh) {
    const refreshed = await tryRefresh(session);
    if (refreshed) return request<T>(path, options, false);
  }

  if (!res.ok) {
    let data: unknown = null;
    try {
      data = await res.json();
    } catch {
      /* ignore */
    }
    const msg =
      (data as { detail?: string })?.detail || `HTTP ${res.status}`;
    throw new ApiError(res.status, msg, data);
  }
  if (res.status === 204) return undefined as T;
  const ct = res.headers.get("content-type") || "";
  if (!ct.includes("application/json")) return (await res.text()) as unknown as T;
  return (await res.json()) as T;
}

async function tryRefresh(session: Session): Promise<boolean> {
  try {
    const res = await fetch(`${API_BASE}/auth/refresh/`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ refresh: session.refresh }),
    });
    if (!res.ok) {
      setSession(null);
      return false;
    }
    const data = (await res.json()) as { access: string; refresh?: string };
    setSession({
      ...session,
      access: data.access,
      refresh: data.refresh ?? session.refresh,
    });
    return true;
  } catch {
    return false;
  }
}

export const api = {
  get: <T>(path: string) => request<T>(path),
  post: <T>(path: string, body?: unknown) =>
    request<T>(path, { method: "POST", body: JSON.stringify(body ?? {}) }),
  patch: <T>(path: string, body?: unknown) =>
    request<T>(path, { method: "PATCH", body: JSON.stringify(body ?? {}) }),
  del: <T>(path: string) => request<T>(path, { method: "DELETE" }),
};

export async function login(email: string, password: string): Promise<Session> {
  const res = await fetch(`${API_BASE}/auth/login/`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ email, password }),
  });
  if (!res.ok) throw new ApiError(res.status, "Неверный логин или пароль", null);
  const s = (await res.json()) as Session;
  setSession(s);
  return s;
}

export const swrFetcher = <T>(path: string) => api.get<T>(path);

/** Authorized file download (e.g. CSV exports) — saves via a blob link. */
export async function downloadFile(path: string, filename: string) {
  const session = getSession();
  const res = await fetch(`${API_BASE}${path}`, {
    headers: session?.access ? { Authorization: `Bearer ${session.access}` } : {},
  });
  if (!res.ok) throw new ApiError(res.status, `HTTP ${res.status}`, null);
  const blob = await res.blob();
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  a.click();
  URL.revokeObjectURL(url);
}
