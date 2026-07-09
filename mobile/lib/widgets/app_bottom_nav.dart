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

  static const _barColor = Colors.white;

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
      items.insert(items.length ~/ 2, const SizedBox(width: 78));
    }

    return SafeArea(
      top: false,
      child: Container(
        height: 104,
        color: AppColors.bg,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 20,
              right: 20,
              bottom: 6,
              child: Container(
                height: 76,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: _barColor,
                  borderRadius: BorderRadius.circular(42),
                  border: Border.all(color: AppColors.line),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 24,
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
                bottom: 48,
                child: Material(
                  color: Colors.transparent,
                  child: Center(
                    child: _CenterButton(icon: centerIcon, onTap: onCenter!),
                  ),
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
    final color = active ? Colors.white : AppColors.muted;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF202124) : Colors.transparent,
            borderRadius: BorderRadius.circular(30),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.16),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                scale: active ? 1.06 : 1.0,
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOut,
                child: Icon(
                  active ? dest.activeIcon : dest.icon,
                  color: color,
                  size: active ? 22 : 23,
                ),
              ),
              const SizedBox(height: 3),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 260),
                style: TextStyle(
                  color: color,
                  fontSize: 10.5,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                ),
                child: Text(
                  dest.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
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
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(widget.icon, color: AppColors.onBrand, size: 28),
        ),
      ),
    );
  }
}
