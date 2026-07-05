export const TRIP_STATUS: Record<string, { label: string; cls: string }> = {
  created: { label: "Создан", cls: "bg-gray-100 text-gray-700" },
  waiting_payment: { label: "Ждёт оплаты", cls: "bg-amber-100 text-amber-700" },
  paid: { label: "Оплачен", cls: "bg-emerald-100 text-emerald-700" },
  driver_assigned: { label: "Водитель назначен", cls: "bg-blue-100 text-blue-700" },
  driver_on_way: { label: "Водитель выехал", cls: "bg-blue-100 text-blue-700" },
  driver_arrived: { label: "Водитель прибыл", cls: "bg-indigo-100 text-indigo-700" },
  child_picked_up: { label: "Ребёнок забран", cls: "bg-indigo-100 text-indigo-700" },
  in_progress: { label: "В пути", cls: "bg-violet-100 text-violet-700" },
  child_delivered: { label: "Доставлен", cls: "bg-teal-100 text-teal-700" },
  completed: { label: "Завершён", cls: "bg-emerald-100 text-emerald-700" },
  cancelled: { label: "Отменён", cls: "bg-red-100 text-red-700" },
};

export const PAYMENT_STATUS: Record<string, { label: string; cls: string }> = {
  unpaid: { label: "Не оплачен", cls: "bg-gray-100 text-gray-600" },
  pending: { label: "В обработке", cls: "bg-amber-100 text-amber-700" },
  paid: { label: "Оплачен", cls: "bg-emerald-100 text-emerald-700" },
  refunded: { label: "Возврат", cls: "bg-orange-100 text-orange-700" },
  failed: { label: "Ошибка", cls: "bg-red-100 text-red-700" },
};

export function statusBadge(map: typeof TRIP_STATUS, key: string) {
  return map[key] ?? { label: key, cls: "bg-gray-100 text-gray-600" };
}

export const DOC_STATUS: Record<string, { label: string; cls: string }> = {
  pending: { label: "На проверке", cls: "bg-amber-100 text-amber-700" },
  approved: { label: "Одобрен", cls: "bg-emerald-100 text-emerald-700" },
  rejected: { label: "Отклонён", cls: "bg-red-100 text-red-700" },
};

export const ACTIVE_STATUSES = [
  "driver_assigned",
  "driver_on_way",
  "driver_arrived",
  "child_picked_up",
  "in_progress",
  "child_delivered",
];
