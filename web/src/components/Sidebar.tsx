"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  Bell,
  Car,
  ClipboardList,
  CreditCard,
  Download,
  FileText,
  Landmark,
  LayoutDashboard,
  LogOut,
  MapPinned,
  MessageCircle,
  Percent,
  Settings,
  ShieldCheck,
  Star,
  Tags,
  TrendingDown,
  TrendingUp,
  Users,
  Wallet,
  type LucideIcon,
} from "lucide-react";
import { useAuth } from "@/lib/auth";
import { ACCESS } from "@/lib/roles";

interface Item {
  href: string;
  label: string;
  Icon: LucideIcon;
}

const ITEMS: Item[] = [
  { href: "/dashboard", label: "Дашборд", Icon: LayoutDashboard },
  { href: "/trips", label: "Заказы", Icon: ClipboardList },
  { href: "/map", label: "Карта поездок", Icon: MapPinned },
  { href: "/drivers", label: "Водители", Icon: Car },
  { href: "/parents", label: "Родители", Icon: Users },
  { href: "/vehicles", label: "Автомобили", Icon: Car },
  { href: "/payments", label: "Платежи", Icon: CreditCard },
  { href: "/payouts", label: "Выплаты", Icon: Wallet },
  { href: "/tariffs", label: "Тарифы", Icon: Percent },
  { href: "/promo-codes", label: "Промокоды", Icon: Tags },
  { href: "/reviews", label: "Отзывы", Icon: Star },
  { href: "/messages", label: "Сообщения", Icon: MessageCircle },
  { href: "/notifications", label: "Уведомления", Icon: Bell },
  { href: "/reports", label: "Фин. отчёты", Icon: FileText },
  { href: "/income", label: "Доходы", Icon: TrendingUp },
  { href: "/expenses", label: "Расходы", Icon: TrendingDown },
  { href: "/bank", label: "Банк", Icon: Landmark },
  { href: "/documents", label: "Акты / документы", Icon: FileText },
  { href: "/exports", label: "Экспорт", Icon: Download },
  { href: "/settings", label: "Настройки", Icon: Settings },
  { href: "/staff", label: "Роли и сотрудники", Icon: ShieldCheck },
];

const ROLE_LABEL: Record<string, string> = {
  admin: "Админ",
  operator: "Оператор",
  accountant: "Бухгалтер",
};

export default function Sidebar() {
  const pathname = usePathname();
  const { session, signOut } = useAuth();
  const role = session?.role;
  const initial = (session?.email?.[0] ?? "?").toUpperCase();

  const items = ITEMS.filter(
    (item) =>
      role &&
      ACCESS.find((rule) => item.href.startsWith(rule.prefix))?.roles.includes(
        role
      )
  );

  return (
    <aside className="w-64 shrink-0 bg-white border-r border-line h-screen sticky top-0 overflow-y-auto flex flex-col">
      <div className="px-5 py-5 flex items-center gap-3">
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img
          src="/logo.png"
          alt="Детское такси"
          className="h-11 w-11 object-contain"
        />
        <div className="font-extrabold leading-tight text-[15px]">
          Детское такси
          <div className="text-[11px] font-medium text-muted">кабинет</div>
        </div>
      </div>

      <nav className="space-y-0.5 flex-1 mt-3" aria-label="Основное меню">
        {items.map(({ href, label, Icon }) => {
          const active = pathname === href || pathname.startsWith(`${href}/`);
          return (
            <Link
              key={href}
              href={href}
              className={`group relative flex items-center gap-3 px-5 py-2.5 text-sm cursor-pointer transition-colors duration-200 ${
                active
                  ? "bg-brand-soft text-ink font-semibold"
                  : "font-medium text-muted hover:bg-gray-50 hover:text-ink"
              }`}
            >
              {active && (
                <span className="absolute left-0 top-1/2 -translate-y-1/2 h-7 w-1 rounded-r-full bg-brand-dark" />
              )}
              <Icon
                className={`h-[18px] w-[18px] ${
                  active
                    ? "text-brand-dark"
                    : "text-gray-400 group-hover:text-ink"
                }`}
                strokeWidth={2.1}
              />
              {label}
            </Link>
          );
        })}
      </nav>

      <div className="p-3 border-t border-line">
        <div className="flex items-center gap-3 px-2 py-2 mb-1">
          <div className="h-9 w-9 rounded-full bg-brand-soft grid place-items-center text-sm font-bold text-brand-dark">
            {initial}
          </div>
          <div className="min-w-0">
            <div className="text-[13px] font-semibold truncate">
              {session?.email}
            </div>
            <div className="text-[11px] uppercase tracking-wide text-muted">
              {role ? ROLE_LABEL[role] ?? role : ""}
            </div>
          </div>
        </div>
        <button
          className="flex w-full items-center justify-center gap-2 rounded-xl px-3 py-2.5 text-sm font-semibold text-red-600 hover:bg-red-50 cursor-pointer transition-colors duration-200"
          onClick={signOut}
        >
          <LogOut className="h-4 w-4" strokeWidth={2.2} />
          Выйти
        </button>
      </div>
    </aside>
  );
}
