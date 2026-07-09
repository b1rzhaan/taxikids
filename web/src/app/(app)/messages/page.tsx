"use client";

import { Send, MessageCircle, PhoneCall, Bot } from "lucide-react";

const threads = [
  {
    id: 1,
    title: "Мама · заказ #6",
    last: "Нужно уточнить адрес подъезда",
    badge: "AI передал оператору",
  },
  {
    id: 2,
    title: "Водитель Алексей",
    last: "Клиент не отвечает, ожидаю",
    badge: "В работе",
  },
];

export default function MessagesPage() {
  return (
    <div className="space-y-4">
      <div>
        <h1 className="text-2xl font-bold">Сообщения</h1>
        <div className="text-sm text-muted">
          Чат поддержки: сначала отвечает AI, затем оператор продолжает диалог
        </div>
      </div>

      <div className="grid lg:grid-cols-[340px_1fr] gap-4 h-[72vh]">
        <div className="card p-3 overflow-y-auto">
          <div className="space-y-2">
            {threads.map((thread, index) => (
              <button
                key={thread.id}
                className={`w-full text-left rounded-2xl p-4 border transition-colors ${
                  index === 0
                    ? "border-brand bg-brand-soft"
                    : "border-line hover:bg-gray-50"
                }`}
              >
                <div className="font-bold">{thread.title}</div>
                <div className="text-sm text-muted mt-1">{thread.last}</div>
                <span className="badge bg-white text-ink mt-3">{thread.badge}</span>
              </button>
            ))}
          </div>
        </div>

        <div className="card flex flex-col overflow-hidden">
          <div className="px-5 py-4 border-b border-line flex items-center justify-between">
            <div className="flex items-center gap-3">
              <div className="h-10 w-10 rounded-full bg-brand grid place-items-center">
                <MessageCircle className="h-5 w-5 text-ink" />
              </div>
              <div>
                <div className="font-bold">Мама · заказ #6</div>
                <div className="text-xs text-muted">Родитель · онлайн</div>
              </div>
            </div>
            <button className="btn-ghost py-2">
              <PhoneCall className="h-4 w-4" />
              Позвонить
            </button>
          </div>

          <div className="flex-1 p-5 space-y-4 overflow-y-auto bg-gray-50/60">
            <Bubble side="left" icon={Bot} text="AI уточнил проблему: родитель хочет изменить подъезд и время подачи." />
            <Bubble side="right" text="Здравствуйте! Я оператор Детского такси. Сейчас проверю заказ и помогу." />
            <Bubble side="left" text="Спасибо. Нужно забрать ребёнка со второго подъезда." />
          </div>

          <div className="p-4 border-t border-line flex gap-2">
            <input className="input" placeholder="Напишите сообщение..." />
            <button className="btn-brand">
              <Send className="h-4 w-4" />
              Отправить
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}

function Bubble({
  side,
  text,
  icon: Icon,
}: {
  side: "left" | "right";
  text: string;
  icon?: typeof Bot;
}) {
  const mine = side === "right";
  return (
    <div className={`flex ${mine ? "justify-end" : "justify-start"}`}>
      <div
        className={`max-w-[70%] rounded-2xl px-4 py-3 text-sm shadow-sm ${
          mine ? "bg-brand text-ink" : "bg-white border border-line"
        }`}
      >
        {Icon && <Icon className="h-4 w-4 inline mr-1 text-brand-dark" />}
        {text}
      </div>
    </div>
  );
}
