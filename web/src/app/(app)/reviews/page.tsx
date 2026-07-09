"use client";

import { Star } from "lucide-react";
import ModulePage from "@/components/ModulePage";

export default function ReviewsPage() {
  return (
    <ModulePage
      title="Отзывы"
      subtitle="Оценки родителей и водителей, спорные поездки и качество сервиса."
      icon={Star}
      sections={[
        { title: "Рейтинги", items: ["Оценки заказов", "Комментарии", "Средний рейтинг водителей"] },
        { title: "Контроль качества", items: ["Жалобы", "Повторная связь", "Внутренние заметки"] },
      ]}
    />
  );
}
