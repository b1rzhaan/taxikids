"use client";

import { TrendingUp } from "lucide-react";
import ModulePage from "@/components/ModulePage";

export default function IncomePage() {
  return (
    <ModulePage
      title="Доходы"
      subtitle="Доходы сервиса по поездкам, оплатам и комиссиям."
      icon={TrendingUp}
      sections={[
        { title: "Источники", items: ["Онлайн оплаты", "Наличные поездки", "Комиссия сервиса"] },
        { title: "Разрезы", items: ["По дням", "По водителям", "По тарифам"] },
      ]}
    />
  );
}
