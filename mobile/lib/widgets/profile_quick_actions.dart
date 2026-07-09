import 'package:flutter/material.dart';
import '../core/theme.dart';

class ProfileQuickAction {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const ProfileQuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}

class ProfileQuickActions extends StatelessWidget {
  final List<ProfileQuickAction> actions;

  const ProfileQuickActions({super.key, required this.actions})
    : assert(actions.length == 4);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.055),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          for (var i = 0; i < actions.length; i++) ...[
            Expanded(child: ProfileQuickActionItem(action: actions[i])),
            if (i != actions.length - 1)
              Container(
                width: 1,
                height: 42,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                color: AppColors.line,
              ),
          ],
        ],
      ),
    );
  }
}

class ProfileQuickActionItem extends StatefulWidget {
  final ProfileQuickAction action;

  const ProfileQuickActionItem({super.key, required this.action});

  @override
  State<ProfileQuickActionItem> createState() => _ProfileQuickActionItemState();
}

class _ProfileQuickActionItemState extends State<ProfileQuickActionItem> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.97 : 1,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: widget.action.onTap,
          onTapDown: (_) => _setPressed(true),
          onTapCancel: () => _setPressed(false),
          onTapUp: (_) => _setPressed(false),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  widget.action.icon,
                  color: const Color(0xFFFFC107),
                  size: 25,
                ),
                const SizedBox(height: 8),
                Text(
                  widget.action.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
