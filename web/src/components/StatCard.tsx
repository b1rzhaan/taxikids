export default function StatCard({
  label,
  value,
  delta,
  deltaTitle = "к прошлой неделе",
  sub,
  accent = false,
}: {
  label: string;
  value: React.ReactNode;
  delta?: number | null;
  deltaTitle?: string;
  sub?: string;
  accent?: boolean;
}) {
  return (
    <div className={`card p-5 ${accent ? "ring-1 ring-brand/60" : ""}`}>
      <div className="text-[11px] font-semibold uppercase tracking-wider text-muted">
        {label}
      </div>
      <div className="mt-2 flex items-end justify-between gap-2">
        <div className="text-2xl font-extrabold tracking-tight">{value}</div>
        {typeof delta === "number" && (
          <span
            title={deltaTitle}
            className={`badge ${
              delta >= 0
                ? "bg-emerald-50 text-emerald-600"
                : "bg-red-50 text-red-500"
            }`}
          >
            {delta >= 0 ? "+" : ""}
            {delta.toFixed(1)}%
          </span>
        )}
      </div>
      {sub && <div className="mt-1 text-xs text-muted">{sub}</div>}
    </div>
  );
}
