"use client";

export default function Donut({
  percent,
  color = "#FFCE00",
  track = "#F1F2F4",
  size = 116,
  stroke = 12,
  label,
  children,
}: {
  percent: number;
  color?: string;
  track?: string;
  size?: number;
  stroke?: number;
  label?: string;
  children?: React.ReactNode;
}) {
  const r = (size - stroke) / 2;
  const c = 2 * Math.PI * r;
  const p = Math.max(0, Math.min(100, percent));

  return (
    <div className="flex flex-col items-center gap-2">
      <div className="relative" style={{ width: size, height: size }}>
        <svg width={size} height={size} role="img" aria-label={`${label ?? ""} ${Math.round(p)}%`}>
          <circle cx={size / 2} cy={size / 2} r={r} fill="none" stroke={track} strokeWidth={stroke} />
          <circle
            cx={size / 2}
            cy={size / 2}
            r={r}
            fill="none"
            stroke={color}
            strokeWidth={stroke}
            strokeLinecap="round"
            strokeDasharray={`${(c * p) / 100} ${c}`}
            transform={`rotate(-90 ${size / 2} ${size / 2})`}
            className="transition-all duration-500"
          />
        </svg>
        <div className="absolute inset-0 grid place-items-center text-center">{children}</div>
      </div>
      {label && <div className="text-xs text-muted text-center">{label}</div>}
    </div>
  );
}
