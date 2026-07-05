"use client";

import { useRef, useState } from "react";

export interface ChartPoint {
  label: string;
  value: number;
  hint?: string;
}

const W = 640;
const H = 240;
const PAD = { l: 42, r: 14, t: 14, b: 28 };

function niceCeil(v: number) {
  const p = 10 ** Math.floor(Math.log10(Math.max(1, v)));
  const m = v / p;
  const nice = m <= 1 ? 1 : m <= 2 ? 2 : m <= 5 ? 5 : 10;
  return nice * p;
}

/** Catmull-Rom → cubic bezier for a smooth line through all points. */
function smoothPath(pts: ReadonlyArray<readonly [number, number]>) {
  if (pts.length === 0) return "";
  if (pts.length === 1) return `M ${pts[0][0]} ${pts[0][1]}`;
  let d = `M ${pts[0][0]} ${pts[0][1]}`;
  for (let i = 0; i < pts.length - 1; i++) {
    const [x0, y0] = pts[Math.max(0, i - 1)];
    const [x1, y1] = pts[i];
    const [x2, y2] = pts[i + 1];
    const [x3, y3] = pts[Math.min(pts.length - 1, i + 2)];
    d += ` C ${x1 + (x2 - x0) / 6} ${y1 + (y2 - y0) / 6}, ${x2 - (x3 - x1) / 6} ${
      y2 - (y3 - y1) / 6
    }, ${x2} ${y2}`;
  }
  return d;
}

export default function LineChart({
  data,
  formatValue = (n) => String(n),
}: {
  data: ChartPoint[];
  formatValue?: (n: number) => string;
}) {
  const wrapRef = useRef<HTMLDivElement>(null);
  const [hover, setHover] = useState<number | null>(null);

  const iw = W - PAD.l - PAD.r;
  const ih = H - PAD.t - PAD.b;
  const max = niceCeil(Math.max(1, ...data.map((d) => d.value)));
  const x = (i: number) =>
    PAD.l + (data.length <= 1 ? iw / 2 : (i / (data.length - 1)) * iw);
  const y = (v: number) => PAD.t + ih - (v / max) * ih;
  const pts = data.map((d, i) => [x(i), y(d.value)] as const);
  const line = smoothPath(pts);
  const area =
    pts.length > 1
      ? `${line} L ${pts[pts.length - 1][0]} ${PAD.t + ih} L ${pts[0][0]} ${PAD.t + ih} Z`
      : "";

  const labelStep = Math.max(1, Math.ceil(data.length / 6));
  const ticks = [0, 1, 2, 3, 4].map((k) => (max * k) / 4);

  function onMove(e: React.MouseEvent) {
    const rect = wrapRef.current?.getBoundingClientRect();
    if (!rect || data.length === 0) return;
    const fx = ((e.clientX - rect.left) / rect.width) * W;
    const i = Math.round(((fx - PAD.l) / iw) * (data.length - 1));
    setHover(Math.max(0, Math.min(data.length - 1, i)));
  }

  const h = hover !== null ? data[hover] : null;

  return (
    <div
      ref={wrapRef}
      className="relative"
      onMouseMove={onMove}
      onMouseLeave={() => setHover(null)}
    >
      <svg viewBox={`0 0 ${W} ${H}`} className="w-full h-auto block" role="img" aria-label="График поездок по дням">
        <defs>
          <linearGradient id="chartFill" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor="#FFCE00" stopOpacity="0.28" />
            <stop offset="100%" stopColor="#FFCE00" stopOpacity="0.02" />
          </linearGradient>
        </defs>

        {ticks.map((t) => (
          <g key={t}>
            <line x1={PAD.l} x2={W - PAD.r} y1={y(t)} y2={y(t)} stroke="#EFF1F4" strokeWidth="1" />
            <text x={PAD.l - 8} y={y(t) + 3.5} textAnchor="end" fontSize="10" fill="#8A8F98">
              {t % 1 === 0 ? t : t.toFixed(1)}
            </text>
          </g>
        ))}

        {area && <path d={area} fill="url(#chartFill)" />}
        <path d={line} fill="none" stroke="#F5B800" strokeWidth="2.5" strokeLinecap="round" />

        {data.map((d, i) =>
          i % labelStep === 0 ? (
            <text key={i} x={x(i)} y={H - 8} textAnchor="middle" fontSize="10" fill="#8A8F98">
              {d.label}
            </text>
          ) : null
        )}

        {hover !== null && (
          <g>
            <line
              x1={x(hover)}
              x2={x(hover)}
              y1={PAD.t}
              y2={PAD.t + ih}
              stroke="#D9DCE1"
              strokeWidth="1"
              strokeDasharray="4 3"
            />
            <circle cx={x(hover)} cy={y(data[hover].value)} r="5" fill="#FFCE00" stroke="#15161A" strokeWidth="2" />
          </g>
        )}
      </svg>

      {h && hover !== null && (
        <div
          className="pointer-events-none absolute z-10 -translate-x-1/2 -translate-y-full
                     rounded-lg bg-ink text-white text-xs px-2.5 py-1.5 shadow-soft whitespace-nowrap"
          style={{
            left: `${(x(hover) / W) * 100}%`,
            top: `${(y(h.value) / H) * 100}%`,
            marginTop: "-8px",
          }}
        >
          <div className="font-semibold">{h.label}</div>
          <div className="opacity-80">{h.hint ?? formatValue(h.value)}</div>
        </div>
      )}
    </div>
  );
}
