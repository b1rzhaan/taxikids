"use client";

import { Bell } from "lucide-react";
import ModulePage from "@/components/ModulePage";

export default function NotificationsPage() {
  return (
    <ModulePage
      title="Уведомления"
      subtitle="Оповещения для родителей, водителей и сотрудников кабинета."
      icon={Bell}
      status="ready"
      sections={[
        { title: "Каналы", items: ["Push", "Email", "Системные уведомления"] },
        { title: "События", items: ["Статус заказа", "Оплата", "Назначение водителя", "SOS"] },
      ]}
    />
  );
}
