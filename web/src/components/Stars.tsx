import { Star } from "lucide-react";

export default function Stars({
  value,
  comment,
  size = 3.5,
}: {
  value: number | null | undefined;
  comment?: string;
  size?: number;
}) {
  if (!value) return <span className="text-muted text-sm">—</span>;
  return (
    <div
      className="flex items-center gap-0.5"
      title={comment || `Оценка: ${value} из 5`}
      aria-label={`Оценка ${value} из 5`}
    >
      {[1, 2, 3, 4, 5].map((i) => (
        <Star
          key={i}
          style={{ width: `${size * 4}px`, height: `${size * 4}px` }}
          className={
            i <= value
              ? "text-brand-dark fill-brand"
              : "text-gray-200 fill-gray-100"
          }
        />
      ))}
    </div>
  );
}
