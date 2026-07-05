import 'package:flutter/material.dart';

class TripStatusInfo {
  final String label;
  final Color color;
  const TripStatusInfo(this.label, this.color);
}

const _c = {
  'created': TripStatusInfo('Создан', Color(0xFF6B7280)),
  'waiting_payment': TripStatusInfo('Ожидает оплаты', Color(0xFFB45309)),
  'paid': TripStatusInfo('Оплачен', Color(0xFF16A34A)),
  'driver_assigned': TripStatusInfo('Водитель назначен', Color(0xFF2563EB)),
  'driver_on_way': TripStatusInfo('Водитель выехал', Color(0xFF2563EB)),
  'driver_arrived': TripStatusInfo('Водитель прибыл', Color(0xFF4F46E5)),
  'child_picked_up': TripStatusInfo('Ребёнок забран', Color(0xFF4F46E5)),
  'in_progress': TripStatusInfo('В пути', Color(0xFF7C3AED)),
  'child_delivered': TripStatusInfo('Доставлен', Color(0xFF0D9488)),
  'completed': TripStatusInfo('Завершён', Color(0xFF16A34A)),
  'cancelled': TripStatusInfo('Отменён', Color(0xFFDC2626)),
};

TripStatusInfo statusInfo(String key) =>
    _c[key] ?? const TripStatusInfo('—', Color(0xFF6B7280));

class StatusChip extends StatelessWidget {
  final String status;
  const StatusChip(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final info = statusInfo(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: info.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        info.label,
        style: TextStyle(
          color: info.color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
