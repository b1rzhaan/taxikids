"use client";

import { FileText } from "lucide-react";
import ModulePage from "@/components/ModulePage";

export default function DocumentsPage() {
  return (
    <ModulePage
      title="Акты / Документы"
      subtitle="Документы для бухгалтерии, водителей и корпоративных клиентов."
      icon={FileText}
      sections={[
        { title: "Документы", items: ["Акты", "Счета", "Реестры выплат"] },
        { title: "Форматы", items: ["PDF", "Excel", "Печать"] },
      ]}
    />
  );
}
