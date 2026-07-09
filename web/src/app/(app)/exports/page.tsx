"use client";

import { Download } from "lucide-react";
import ModulePage from "@/components/ModulePage";

export default function ExportsPage() {
  return (
    <ModulePage
      title="Экспорт"
      subtitle="Выгрузки для бухгалтерии и операционного контроля."
      icon={Download}
      status="ready"
      sections={[
        { title: "Форматы", items: ["Excel", "PDF", "CSV"] },
        { title: "Данные", items: ["Заказы", "Платежи", "Выплаты", "Водители"] },
      ]}
    />
  );
}
