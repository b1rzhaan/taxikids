"use client";

import { Tags } from "lucide-react";
import ModulePage from "@/components/ModulePage";

export default function PromoCodesPage() {
  return (
    <ModulePage
      title="Промокоды"
      subtitle="Скидки, кампании и ограничения по клиентам или зонам."
      icon={Tags}
      sections={[
        { title: "Кампании", items: ["Скидка на первую поездку", "Период действия", "Лимиты"] },
        { title: "Контроль", items: ["История применений", "Бюджет", "Отключение"] },
      ]}
    />
  );
}
