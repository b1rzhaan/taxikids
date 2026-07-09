import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/models.dart';

class TripChildAvatar extends StatelessWidget {
  final Trip trip;
  final double radius;
  final int maxVisible;

  const TripChildAvatar({
    super.key,
    required this.trip,
    this.radius = 22,
    this.maxVisible = 2,
  });

  @override
  Widget build(BuildContext context) {
    final children = trip.children;
    if (children.length <= 1) {
      return _framed(
        PhotoAvatar(
          name: trip.displayChildName,
          photoUrl: trip.primaryChildPhoto,
          radius: radius,
        ),
      );
    }

    final visible = children.take(maxVisible).toList();
    final overlap = radius * 1.35;
    final width = (radius * 2) + (visible.length - 1) * overlap;
    return SizedBox(
      width: width,
      height: radius * 2 + 4,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < visible.length; i++)
            Positioned(
              left: i * overlap,
              child: _framed(
                PhotoAvatar(
                  name: visible[i].fullName,
                  photoUrl: visible[i].photo,
                  radius: radius,
                ),
              ),
            ),
          if (children.length > maxVisible)
            Positioned(
              right: -5,
              bottom: -2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Text(
                  '+${children.length - maxVisible}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _framed(Widget child) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}
