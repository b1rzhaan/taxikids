"use client";

import { FileText } from "lucide-react";
import ModulePage from "@/components/ModulePage";

export default function ReportsPage() {
  return (
    <ModulePage
      title="Финансовые отчёты"
      subtitle="Сводки по оплатам, выплатам, доходам и периодам."
      icon={FileText}
      sections={[
        { title: "Отчёты", items: ["День", "Неделя", "Месяц", "Произвольный период"] },
        { title: "Метрики", items: ["Валовая выручка", "Комиссия сервиса", "Выплаты водителям"] },
      ]}
    />
  );
}
