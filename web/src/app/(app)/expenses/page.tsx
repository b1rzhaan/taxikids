"use client";

import { TrendingDown } from "lucide-react";
import ModulePage from "@/components/ModulePage";

export default function ExpensesPage() {
  return (
    <ModulePage
      title="Расходы"
      subtitle="Операционные расходы, возвраты и корректировки."
      icon={TrendingDown}
      sections={[
        { title: "Категории", items: ["Возвраты", "Бонусы", "Компенсации", "Сервисные расходы"] },
        { title: "Контроль", items: ["Подтверждение", "Комментарий бухгалтера", "История изменений"] },
      ]}
    />
  );
}
