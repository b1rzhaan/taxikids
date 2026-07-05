"use client";

export interface BarPoint {
  label: string;
  value: number;
  hint?: string;
}

const W = 320;
const H = 170;
const PAD = { l: 6, r: 6, t: 20, b: 22 };

export default function BarChart({ data }: { data: BarPoint[] }) {
  const iw = W - PAD.l - PAD.r;
  const ih = H - PAD.t - PAD.b;
  const max = Math.max(1, ...data.map((d) => d.value));
  const step = iw / Math.max(1, data.length);
  const bw = Math.min(26, step * 0.55);

  return (
    <svg viewBox={`0 0 ${W} ${H}`} className="w-full h-auto block" role="img" aria-label="Доход по дням недели">
      {data.map((d, i) => {
        const h = Math.max(3, (d.value / max) * ih);
        const x = PAD.l + step * i + (step - bw) / 2;
        const y = PAD.t + ih - h;
        return (
          <g key={i}>
            <title>{d.hint ?? `${d.label}: ${d.value}`}</title>
            <rect
              x={x}
              y={y}
              width={bw}
              height={h}
              rx={5}
              fill={d.value > 0 ? "#FFCE00" : "#F1F2F4"}
              className="transition-opacity duration-150 hover:opacity-75"
            />
            <text
              x={PAD.l + step * i + step / 2}
              y={H - 6}
              textAnchor="middle"
              fontSize="10"
              fill="#8A8F98"
            >
              {d.label}
            </text>
          </g>
        );
      })}
    </svg>
  );
}
