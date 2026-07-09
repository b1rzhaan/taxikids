"use client";

import { ShieldCheck } from "lucide-react";
import ModulePage from "@/components/ModulePage";

export default function StaffPage() {
  return (
    <ModulePage
      title="Роли и сотрудники"
      subtitle="Управление доступом: администратор, оператор, бухгалтер."
      icon={ShieldCheck}
      sections={[
        { title: "Роли", items: ["Администратор", "Оператор", "Бухгалтер"] },
        { title: "Доступы", items: ["Полное управление", "Операционная работа", "Финансовый контур"] },
      ]}
    />
  );
}
