import 'package:flutter/material.dart';
import '../core/theme.dart';

/// One side destination (icon + label) of [AppBottomNav].
class NavDest {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const NavDest(this.icon, this.activeIcon, this.label);
}

/// Premium floating bottom navigation: dark rounded bar + a yellow center
/// action button that overlaps the bar. Fully custom (no BottomNavigationBar).
class AppBottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  final List<NavDest> destinations;
  // When set, a yellow floating center action button is shown between the
  // 2nd and 3rd items. Omit it (e.g. for the driver) for a plain bar.
  final VoidCallback? onCenter;
  final IconData centerIcon;

  const AppBottomNav({
    super.key,
    required this.index,
    required this.onTap,
    required this.destinations,
    this.onCenter,
    this.centerIcon = Icons.local_taxi,
  });

  static const _barColor = Color(0xFF151515);

  @override
  Widget build(BuildContext context) {
    final hasCenter = onCenter != null;
    final List<Widget> items = [
      for (var i = 0; i < destinations.length; i++)
        Expanded(
          child: NavigationItem(
            dest: destinations[i],
            active: index == i,
            onTap: () => onTap(i),
          ),
        ),
    ];
    // Insert the gap for the floating center button in the middle.
    if (hasCenter) {
      items.insert(items.length ~/ 2, const SizedBox(width: 68));
    }

    return SafeArea(
      top: false,
      child: SizedBox(
        height: 108,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.bg.withValues(alpha: 0),
                      AppColors.bg.withValues(alpha: 0.92),
                      AppColors.bg,
                    ],
                    stops: const [0, 0.42, 1],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 18,
              right: 18,
              bottom: 12,
              child: Container(
                height: 72,
                decoration: BoxDecoration(
                  color: _barColor,
                  borderRadius: BorderRadius.circular(40),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.45),
                      blurRadius: 26,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: Row(children: items),
                ),
              ),
            ),
            if (hasCenter)
              Positioned(
                left: 0,
                right: 0,
                bottom: 44,
                child: Center(
                  child: _CenterButton(icon: centerIcon, onTap: onCenter!),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A single tappable nav destination with scale + colour + label animation.
class NavigationItem extends StatelessWidget {
  final NavDest dest;
  final bool active;
  final VoidCallback onTap;
  const NavigationItem({
    super.key,
    required this.dest,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? Colors.white : const Color(0xFF787878);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: active ? 1.12 : 1.0,
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOut,
              child: Icon(
                active ? dest.activeIcon : dest.icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 260),
              style: TextStyle(
                color: color,
                fontSize: 10.5,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
              child: Text(dest.label),
            ),
          ],
        ),
      ),
    );
  }
}

class _CenterButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CenterButton({required this.icon, required this.onTap});

  @override
  State<_CenterButton> createState() => _CenterButtonState();
}

class _CenterButtonState extends State<_CenterButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.9 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: Container(
          height: 64,
          width: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.brand, AppColors.brandDark],
            ),
            border: Border.all(color: AppColors.bg, width: 4),
            boxShadow: [
              BoxShadow(
                color: AppColors.brand.withValues(alpha: 0.55),
                blurRadius: 18,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Icon(widget.icon, color: AppColors.onBrand, size: 28),
        ),
      ),
    );
  }
}
