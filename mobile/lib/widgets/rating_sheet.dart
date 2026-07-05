import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../core/theme.dart';
import '../services/services.dart';

/// Shows a modal star-rating sheet for a completed trip.
/// Returns true if a rating was submitted.
Future<bool?> showRatingSheet(
  BuildContext context, {
  required int tripId,
  required String title,
  String subtitle = '',
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _RatingSheet(tripId: tripId, title: title, subtitle: subtitle),
  );
}

class _RatingSheet extends StatefulWidget {
  final int tripId;
  final String title;
  final String subtitle;
  const _RatingSheet({
    required this.tripId,
    required this.title,
    required this.subtitle,
  });

  @override
  State<_RatingSheet> createState() => _RatingSheetState();
}

class _RatingSheetState extends State<_RatingSheet> {
  int _stars = 0;
  final _comment = TextEditingController();
  bool _saving = false;

  Future<void> _submit() async {
    if (_stars == 0) return;
    setState(() => _saving = true);
    try {
      await TripsService.rate(widget.tripId, _stars, comment: _comment.text.trim());
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(ApiClient.errorMessage(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
            Text(widget.title,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            if (widget.subtitle.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(widget.subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.muted)),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final filled = i < _stars;
                return IconButton(
                  iconSize: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  onPressed: () => setState(() => _stars = i + 1),
                  icon: Icon(filled ? Icons.star : Icons.star_border,
                      color: filled ? AppColors.brand : Colors.grey.shade400),
                );
              }),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _comment,
              maxLines: 2,
              decoration: const InputDecoration(
                  hintText: 'Комментарий (необязательно)'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: (_stars == 0 || _saving) ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.ink))
                    : const Text('Отправить оценку'),
              ),
            ),
            TextButton(
              onPressed: _saving ? null : () => Navigator.pop(context, false),
              child: const Text('Позже', style: TextStyle(color: AppColors.muted)),
            ),
          ],
        ),
      ),
    );
  }
}
