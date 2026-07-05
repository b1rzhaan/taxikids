import 'package:flutter/material.dart';
import '../core/theme.dart';

/// Shared premium UI building blocks for the dark/yellow design system.

/// Section title with an optional trailing action ("Смотреть все").
class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const SectionHeader(this.title, {super.key, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        if (action != null)
          GestureDetector(
            onTap: onAction,
            child: Text(action!,
                style: const TextStyle(
                    color: AppColors.brand,
                    fontWeight: FontWeight.w700,
                    fontSize: 13)),
          ),
      ],
    );
  }
}

/// An icon inside a soft rounded square — the app's standard glyph container.
class SoftIcon extends StatelessWidget {
  final IconData icon;
  final Color? bg;
  final Color? fg;
  final double size;
  const SoftIcon(this.icon, {super.key, this.bg, this.fg, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        color: bg ?? AppColors.surface2,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(icon, color: fg ?? AppColors.brand, size: size * 0.5),
    );
  }
}

/// Friendly full-width empty state: glyph, title, subtitle, optional CTA.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          Container(
            height: 64,
            width: 64,
            decoration: BoxDecoration(
              color: AppColors.brand.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.brand, size: 30),
          ),
          const SizedBox(height: 14),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted, fontSize: 13)),
          ],
          if (actionLabel != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(onPressed: onAction, child: Text(actionLabel!)),
            ),
          ],
        ],
      ),
    );
  }
}

/// Licence-plate style badge, e.g. AB6299ZG.
class PlateBadge extends StatelessWidget {
  final String plate;
  const PlateBadge(this.plate, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(plate,
          style: const TextStyle(
              color: Color(0xFF141414),
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              fontSize: 13)),
    );
  }
}

/// A compact stat inside a rounded chip (icon + value + label), like the
/// "4 Seat / 482 Trip" chips in the reference driver card.
class StatPill extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const StatPill(
      {super.key, required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.brand),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 13, height: 1.1)),
              Text(label,
                  style: const TextStyle(color: AppColors.muted, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

/// A soft live "pulse" glow around [child] — a breathing shadow on the
/// OUTSIDE of the block. Signals an active/live element (e.g. the current trip).
class PulseGlow extends StatefulWidget {
  final Widget child;
  final double radius;
  final Color color;
  const PulseGlow({
    super.key,
    required this.child,
    this.radius = 22,
    this.color = AppColors.brand,
  });

  @override
  State<PulseGlow> createState() => _PulseGlowState();
}

class _PulseGlowState extends State<PulseGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_c.value);
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.12 + 0.30 * t),
                blurRadius: 6 + 20 * t,
                spreadRadius: 1 + 2 * t,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Round icon button on a surface circle (top-bar actions on maps etc.).
class CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color? bg;
  const CircleIconButton(this.icon, {super.key, this.onTap, this.bg});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bg ?? AppColors.surface,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          height: 44,
          width: 44,
          child: Icon(icon, color: AppColors.ink, size: 20),
        ),
      ),
    );
  }
}
