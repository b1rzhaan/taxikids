"use client";

import { Landmark } from "lucide-react";
import ModulePage from "@/components/ModulePage";

export default function BankPage() {
  return (
    <ModulePage
      title="Банковские операции"
      subtitle="Сверка платежей, тестовый Stripe и будущие локальные провайдеры."
      icon={Landmark}
      sections={[
        { title: "Провайдеры", items: ["Stripe test/demo", "Halyk", "Kaspi Pay", "CloudPayments"] },
        { title: "Операции", items: ["Сверка", "Webhook события", "Ошибки оплаты"] },
      ]}
    />
  );
}
