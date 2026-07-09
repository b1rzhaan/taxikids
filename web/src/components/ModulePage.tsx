"use client";

import type { LucideIcon } from "lucide-react";
import { CheckCircle2 } from "lucide-react";

interface ModulePageProps {
  title: string;
  subtitle: string;
  icon: LucideIcon;
  sections: { title: string; items: string[] }[];
  status?: "ready" | "planned";
}

export default function ModulePage({
  title,
  subtitle,
  icon: Icon,
  sections,
  status = "planned",
}: ModulePageProps) {
  return (
    <div className="space-y-5">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <h1 className="text-2xl font-bold">{title}</h1>
          <div className="text-sm text-muted mt-1">{subtitle}</div>
        </div>
        <span
          className={`badge ${
            status === "ready"
              ? "bg-emerald-100 text-emerald-700"
              : "bg-amber-100 text-amber-700"
          }`}
        >
          {status === "ready" ? "Подключено" : "MVP-модуль"}
        </span>
      </div>

      <div className="grid lg:grid-cols-[320px_1fr] gap-4 items-start">
        <div className="card p-5">
          <div className="h-14 w-14 rounded-2xl bg-brand grid place-items-center">
            <Icon className="h-7 w-7 text-ink" />
          </div>
          <div className="mt-4 font-bold text-lg">{title}</div>
          <p className="text-sm text-muted mt-2 leading-6">{subtitle}</p>
        </div>

        <div className="grid md:grid-cols-2 gap-4">
          {sections.map((section) => (
            <div key={section.title} className="card p-5">
              <div className="font-bold mb-3">{section.title}</div>
              <div className="space-y-2">
                {section.items.map((item) => (
                  <div key={item} className="flex items-center gap-2 text-sm">
                    <CheckCircle2 className="h-4 w-4 text-brand-dark shrink-0" />
                    <span>{item}</span>
                  </div>
                ))}
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
