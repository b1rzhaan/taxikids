import { Star } from "lucide-react";
import type { Vehicle } from "@/lib/types";

const COLOR_HEX: Record<string, string> = {
  белый: "#EDEFF2",
  чёрный: "#3A3D45",
  черный: "#3A3D45",
  серый: "#9AA0A8",
  серебристый: "#C4C9CF",
  синий: "#3B82F6",
  красный: "#EF4444",
  жёлтый: "#FFCE00",
  желтый: "#FFCE00",
};

function CarSide({ color }: { color: string }) {
  return (
    <svg viewBox="0 0 260 110" className="w-full h-auto" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Автомобиль">
      {/* body */}
      <path
        d="M18 78 C 18 64 26 58 44 56 L 66 40 C 72 34 80 30 92 30 L 158 30 C 172 30 182 36 192 46 L 204 56 C 228 58 242 64 242 76 L 242 84 C 242 88 238 90 234 90 L 26 90 C 20 90 18 86 18 82 Z"
        fill={color}
        stroke="#15161A"
        strokeOpacity="0.25"
        strokeWidth="2"
      />
      {/* windows */}
      <path d="M74 42 L 92 36 L 118 36 L 118 54 L 62 54 Z" fill="#23252B" opacity="0.85" />
      <path d="M126 36 L 156 36 C 165 36 172 41 180 49 L 184 54 L 126 54 Z" fill="#23252B" opacity="0.85" />
      {/* checker stripe */}
      <g opacity="0.9">
        <rect x="30" y="62" width="10" height="8" fill="#15161A" />
        <rect x="50" y="62" width="10" height="8" fill="#15161A" />
        <rect x="70" y="62" width="10" height="8" fill="#15161A" />
        <rect x="90" y="62" width="10" height="8" fill="#15161A" />
        <rect x="110" y="62" width="10" height="8" fill="#15161A" />
        <rect x="130" y="62" width="10" height="8" fill="#15161A" />
        <rect x="150" y="62" width="10" height="8" fill="#15161A" />
        <rect x="170" y="62" width="10" height="8" fill="#15161A" />
        <rect x="190" y="62" width="10" height="8" fill="#15161A" />
        <rect x="210" y="62" width="10" height="8" fill="#15161A" />
      </g>
      {/* sign */}
      <rect x="118" y="18" width="28" height="12" rx="3" fill="#FFCE00" stroke="#15161A" strokeOpacity="0.3" />
      <text x="132" y="27.5" textAnchor="middle" fontSize="8" fontWeight="bold" fill="#15161A">TAXI</text>
      {/* wheels */}
      <circle cx="70" cy="90" r="14" fill="#1B1D22" />
      <circle cx="70" cy="90" r="6.5" fill="#585D66" />
      <circle cx="192" cy="90" r="14" fill="#1B1D22" />
      <circle cx="192" cy="90" r="6.5" fill="#585D66" />
    </svg>
  );
}

const fmtKm = (n?: number | null) =>
  n ? new Intl.NumberFormat("ru-RU").format(n) + " км" : "—";

export default function CarCard({
  vehicle,
  rating,
}: {
  vehicle: Vehicle;
  rating: string;
}) {
  const hex = COLOR_HEX[(vehicle.color ?? "").toLowerCase()] ?? "#C4C9CF";
  return (
    <div className="rounded-2xl bg-ink text-white p-5 shadow-soft">
      <div className="grid md:grid-cols-[1.1fr_1fr] gap-5 items-center">
        <div className="rounded-xl bg-white/5 p-4">
          <CarSide color={hex} />
          <div className="mt-2 flex items-center justify-between">
            <div className="font-bold">
              {vehicle.make} {vehicle.model}
            </div>
            <div className="flex items-center gap-0.5">
              {[1, 2, 3, 4, 5].map((i) => (
                <Star
                  key={i}
                  className={`h-3.5 w-3.5 ${
                    i <= Math.round(Number(rating))
                      ? "text-brand fill-brand"
                      : "text-white/20 fill-white/10"
                  }`}
                />
              ))}
            </div>
          </div>
        </div>

        <div className="space-y-2.5 text-sm">
          <SpecRow label="Госномер">
            <span className="rounded-md bg-white text-ink font-bold px-2 py-0.5 tracking-wider text-[13px]">
              {vehicle.plate_number}
            </span>
          </SpecRow>
          <SpecRow label="Пробег">
            <b>{fmtKm(vehicle.mileage_km)}</b>
          </SpecRow>
          <SpecRow label="Год выпуска">
            <b>{vehicle.year ?? "—"}</b>
          </SpecRow>
          <SpecRow label="Цвет">
            <span className="inline-flex items-center gap-2">
              <span
                className="h-3 w-3 rounded-full border border-white/30"
                style={{ background: hex }}
              />
              <b>{vehicle.color || "—"}</b>
            </span>
          </SpecRow>
          <SpecRow label="Мест">
            <b>{vehicle.seats ?? "—"}</b>
          </SpecRow>
          <SpecRow label="Техпаспорт">
            <b>{vehicle.tech_passport || "—"}</b>
          </SpecRow>
        </div>
      </div>
    </div>
  );
}

function SpecRow({
  label,
  children,
}: {
  label: string;
  children: React.ReactNode;
}) {
  return (
    <div className="flex items-center justify-between gap-3 border-b border-white/10 pb-2 last:border-0">
      <span className="text-white/60">{label}</span>
      {children}
    </div>
  );
}
