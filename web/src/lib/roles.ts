import type { Role } from "./types";

/** Which cabinet sections each role can open.
 *
 *  admin      — full access to everything;
 *  operator   — daily operations: orders, live map, drivers (no finances);
 *  accountant — finances only: dashboard, payments, payouts. */
export const ACCESS: { prefix: string; roles: Role[] }[] = [
  { prefix: "/dashboard", roles: ["admin", "operator", "accountant"] },
  { prefix: "/trips", roles: ["admin", "operator"] },
  { prefix: "/map", roles: ["admin", "operator"] },
  { prefix: "/drivers", roles: ["admin", "operator"] },
  { prefix: "/parents", roles: ["admin", "operator"] },
  { prefix: "/vehicles", roles: ["admin"] },
  { prefix: "/payments", roles: ["admin", "accountant"] },
  { prefix: "/payouts", roles: ["admin", "accountant"] },
  { prefix: "/tariffs", roles: ["admin"] },
  { prefix: "/promo-codes", roles: ["admin"] },
  { prefix: "/reviews", roles: ["admin", "operator"] },
  { prefix: "/messages", roles: ["admin", "operator"] },
  { prefix: "/notifications", roles: ["admin", "operator", "accountant"] },
  { prefix: "/settings", roles: ["admin", "operator", "accountant"] },
  { prefix: "/staff", roles: ["admin"] },
  { prefix: "/reports", roles: ["admin", "accountant"] },
  { prefix: "/income", roles: ["admin", "accountant"] },
  { prefix: "/expenses", roles: ["admin", "accountant"] },
  { prefix: "/bank", roles: ["admin", "accountant"] },
  { prefix: "/documents", roles: ["admin", "accountant"] },
  { prefix: "/exports", roles: ["admin", "accountant"] },
];

export function canAccess(role: Role | undefined, pathname: string): boolean {
  if (!role) return false;
  const rule = ACCESS.find((r) => pathname.startsWith(r.prefix));
  return rule ? rule.roles.includes(role) : true;
}

/** Landing page after login, per role. */
export function homeFor(role: Role | undefined): string {
  if (role === "operator") return "/trips";
  return "/dashboard";
}
