"use client";

import { useEffect, useMemo, useState } from "react";
import { Bot, CheckCircle2, MessageCircle, PhoneCall, RefreshCw, Send } from "lucide-react";

import { api } from "@/lib/api";
import type { Paginated } from "@/lib/types";

type SupportMessage = {
  id: number;
  sender_name: string;
  sender_email?: string;
  sender_role: "parent" | "driver" | "operator" | "admin" | "accountant" | "ai" | "system";
  body: string;
  created_at: string;
};

type SupportThread = {
  id: number;
  participant_name: string;
  participant_email: string;
  assigned_to_email?: string | null;
  subject: string;
  status: "open" | "in_progress" | "resolved";
  last_message: string;
  last_message_at: string;
  trip_id?: number | null;
  messages: SupportMessage[];
};

const statusLabels: Record<SupportThread["status"], string> = {
  open: "Новый",
  in_progress: "В работе",
  resolved: "Решен",
};

export default function MessagesPage() {
  const [threads, setThreads] = useState<SupportThread[]>([]);
  const [selectedId, setSelectedId] = useState<number | null>(null);
  const [text, setText] = useState("");
  const [loading, setLoading] = useState(true);
  const [sending, setSending] = useState(false);
  const [error, setError] = useState("");

  const selected = useMemo(
    () => threads.find((thread) => thread.id === selectedId) ?? threads[0],
    [threads, selectedId]
  );

  async function loadThreads(nextSelectedId?: number) {
    setError("");
    setLoading(true);
    try {
      const data = await api.get<Paginated<SupportThread> | SupportThread[]>(
        "/notifications/support/threads/?page_size=100"
      );
      const list = Array.isArray(data) ? data : data.results;
      setThreads(list);
      setSelectedId(nextSelectedId ?? list[0]?.id ?? null);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Не удалось загрузить сообщения");
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    loadThreads();
  }, []);

  async function sendMessage() {
    const body = text.trim();
    if (!body || !selected || sending) return;

    setSending(true);
    setError("");
    try {
      const message = await api.post<SupportMessage>(
        `/notifications/support/threads/${selected.id}/messages/`,
        { body }
      );
      setText("");
      setThreads((items) =>
        items
          .map((thread) =>
            thread.id === selected.id
              ? {
                  ...thread,
                  status: thread.status === "open" ? "in_progress" : thread.status,
                  last_message: message.body,
                  last_message_at: message.created_at,
                  messages: [...thread.messages, message],
                }
              : thread
          )
          .sort((a, b) => +new Date(b.last_message_at) - +new Date(a.last_message_at))
      );
      setSelectedId(selected.id);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Не удалось отправить сообщение");
    } finally {
      setSending(false);
    }
  }

  async function resolveThread() {
    if (!selected) return;
    setError("");
    try {
      const updated = await api.post<SupportThread>(
        `/notifications/support/threads/${selected.id}/resolve/`
      );
      setThreads((items) =>
        items.map((thread) => (thread.id === updated.id ? { ...thread, ...updated } : thread))
      );
    } catch (err) {
      setError(err instanceof Error ? err.message : "Не удалось закрыть чат");
    }
  }

  return (
    <div className="space-y-4">
      <div className="flex items-start justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold">Сообщения</h1>
          <div className="text-sm text-muted">
            Чат поддержки: сначала отвечает AI, затем оператор продолжает диалог
          </div>
        </div>
        <button className="btn-ghost py-2" onClick={() => loadThreads(selected?.id)}>
          <RefreshCw className="h-4 w-4" />
          Обновить
        </button>
      </div>

      {error && (
        <div className="rounded-2xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
          {error}
        </div>
      )}

      <div className="grid lg:grid-cols-[340px_1fr] gap-4 h-[72vh]">
        <div className="card p-3 overflow-y-auto">
          {loading ? (
            <div className="p-4 text-sm text-muted">Загрузка сообщений...</div>
          ) : threads.length ? (
            <div className="space-y-2">
              {threads.map((thread) => (
                <button
                  key={thread.id}
                  onClick={() => setSelectedId(thread.id)}
                  className={`w-full text-left rounded-2xl p-4 border transition-colors ${
                    selected?.id === thread.id
                      ? "border-brand bg-brand-soft"
                      : "border-line hover:bg-gray-50"
                  }`}
                >
                  <div className="font-bold">{threadTitle(thread)}</div>
                  <div className="text-sm text-muted mt-1 line-clamp-2">
                    {thread.last_message || "Пока нет сообщений"}
                  </div>
                  <span className="badge bg-white text-ink mt-3">
                    {statusLabels[thread.status]}
                  </span>
                </button>
              ))}
            </div>
          ) : (
            <div className="h-full grid place-items-center px-6 text-center">
              <div>
                <div className="mx-auto h-12 w-12 rounded-2xl bg-brand-soft grid place-items-center">
                  <MessageCircle className="h-6 w-6 text-brand-dark" />
                </div>
                <div className="mt-3 font-semibold">Пока нет обращений</div>
                <div className="mt-1 text-sm text-muted">
                  Когда родитель или водитель напишет в поддержку, чат появится здесь.
                </div>
              </div>
            </div>
          )}
        </div>

        <div className="card flex flex-col overflow-hidden">
          {selected ? (
            <>
              <div className="px-5 py-4 border-b border-line flex items-center justify-between">
                <div className="flex items-center gap-3">
                  <div className="h-10 w-10 rounded-full bg-brand grid place-items-center">
                    <MessageCircle className="h-5 w-5 text-ink" />
                  </div>
                  <div>
                    <div className="font-bold">{threadTitle(selected)}</div>
                    <div className="text-xs text-muted">
                      {selected.participant_email}
                      {selected.assigned_to_email ? ` · оператор: ${selected.assigned_to_email}` : ""}
                    </div>
                  </div>
                </div>
                <div className="flex gap-2">
                  <button className="btn-ghost py-2" type="button">
                    <PhoneCall className="h-4 w-4" />
                    Позвонить
                  </button>
                  <button className="btn-ghost py-2" type="button" onClick={resolveThread}>
                    <CheckCircle2 className="h-4 w-4" />
                    Закрыть
                  </button>
                </div>
              </div>

              <div className="flex-1 p-5 space-y-4 overflow-y-auto bg-gray-50/60">
                {selected.messages.length ? (
                  selected.messages.map((message) => (
                    <Bubble key={message.id} message={message} />
                  ))
                ) : (
                  <div className="h-full grid place-items-center text-sm text-muted">
                    В этом чате пока нет сообщений.
                  </div>
                )}
              </div>

              <form
                className="p-4 border-t border-line flex gap-2"
                onSubmit={(event) => {
                  event.preventDefault();
                  sendMessage();
                }}
              >
                <input
                  className="input"
                  value={text}
                  onChange={(event) => setText(event.target.value)}
                  placeholder="Напишите сообщение..."
                  disabled={sending || selected.status === "resolved"}
                />
                <button
                  className="btn-brand"
                  type="submit"
                  disabled={!text.trim() || sending || selected.status === "resolved"}
                >
                  <Send className="h-4 w-4" />
                  {sending ? "Отправка..." : "Отправить"}
                </button>
              </form>
            </>
          ) : (
            <div className="h-full grid place-items-center text-center px-6">
              <div>
                <div className="mx-auto h-12 w-12 rounded-2xl bg-gray-100 grid place-items-center">
                  <MessageCircle className="h-6 w-6 text-muted" />
                </div>
                <div className="mt-3 font-semibold">Выберите чат</div>
                <div className="mt-1 text-sm text-muted">
                  Здесь будет переписка с родителем или водителем.
                </div>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

function threadTitle(thread: SupportThread) {
  const trip = thread.trip_id ? ` · заказ #${thread.trip_id}` : "";
  return `${thread.participant_name}${trip}`;
}

function Bubble({ message }: { message: SupportMessage }) {
  const mine = ["operator", "admin", "accountant"].includes(message.sender_role);
  const isAi = message.sender_role === "ai";

  return (
    <div className={`flex ${mine ? "justify-end" : "justify-start"}`}>
      <div
        className={`max-w-[70%] rounded-2xl px-4 py-3 text-sm shadow-sm ${
          mine ? "bg-brand text-ink" : "bg-white border border-line"
        }`}
      >
        <div className="mb-1 flex items-center gap-1 text-[11px] font-medium text-muted">
          {isAi && <Bot className="h-3.5 w-3.5 text-brand-dark" />}
          <span>{message.sender_name}</span>
        </div>
        <div className="whitespace-pre-wrap">{message.body}</div>
      </div>
    </div>
  );
}
