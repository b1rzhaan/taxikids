"use client";

import { useEffect } from "react";
import { usePathname, useRouter } from "next/navigation";
import { useAuth, CABINET_ROLES } from "@/lib/auth";
import { canAccess, homeFor } from "@/lib/roles";
import Sidebar from "@/components/Sidebar";
import Topbar from "@/components/Topbar";

export default function AppLayout({ children }: { children: React.ReactNode }) {
  const router = useRouter();
  const pathname = usePathname();
  const { session, ready } = useAuth();

  useEffect(() => {
    if (!ready) return;
    if (!session || !CABINET_ROLES.includes(session.role)) {
      router.replace("/login");
      return;
    }
    // Role-based access: bounce to the role's home page.
    if (!canAccess(session.role, pathname)) {
      router.replace(homeFor(session.role));
    }
  }, [ready, session, router, pathname]);

  if (!ready || !session || !canAccess(session.role, pathname)) {
    return (
      <div className="min-h-screen grid place-items-center text-muted">Загрузка…</div>
    );
  }

  return (
    <div className="flex min-h-screen">
      <Sidebar />
      <div className="flex-1 flex flex-col min-w-0">
        <Topbar />
        <main className="flex-1 p-6 w-full max-w-[1440px]">{children}</main>
      </div>
    </div>
  );
}
