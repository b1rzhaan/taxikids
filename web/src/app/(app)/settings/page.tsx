"use client";

import { Settings } from "lucide-react";
import ModulePage from "@/components/ModulePage";

export default function SettingsPage() {
  return (
    <ModulePage
      title="Настройки системы"
      subtitle="Глобальные параметры сервиса, карт, платежей и безопасности."
      icon={Settings}
      sections={[
        { title: "Сервис", items: ["Название и контакты", "Город и зоны", "Рабочее время"] },
        { title: "Интеграции", items: ["2GIS", "Stripe test", "Groq AI", "Cloudinary"] },
      ]}
    />
  );
}
