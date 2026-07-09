import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// «Детское такси» design tokens — light theme, yellow taxi accent.
class AppColors {
  static const brand = Color(0xFFFFD400); // vivid yellow accent
  static const brandDark = Color(0xFFE6B800);
  static const onBrand = Color(0xFF141414); // dark text ON yellow surfaces
  static const brandSoft = Color(0xFFFFF6CC); // soft yellow card/chip tint
  static const ink = Color(0xFF111827); // primary text on light
  static const muted = Color(0xFF6B7280); // secondary text on light
  static const bg = Color(0xFFFFFFFF); // app background
  static const surface = Color(0xFFFFFFFF); // cards / bottom sheets
  static const surface2 = Color(0xFFF3F4F6); // inputs / elevated chips
  static const line = Color(0xFFE5E7EB); // borders / dividers on light
  static const success = Color(0xFF35C759);
  static const danger = Color(0xFFF04444);
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: const ColorScheme.light(
      primary: AppColors.brand,
      onPrimary: AppColors.onBrand,
      secondary: AppColors.brand,
      onSecondary: AppColors.onBrand,
      surface: AppColors.surface,
      onSurface: AppColors.ink,
      error: AppColors.danger,
    ),
  );

  final text = GoogleFonts.manropeTextTheme(
    base.textTheme,
  ).apply(bodyColor: AppColors.ink, displayColor: AppColors.ink);

  return base.copyWith(
    textTheme: text,
    scaffoldBackgroundColor: AppColors.bg,
    canvasColor: AppColors.bg,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.bg,
      surfaceTintColor: Colors.transparent,
      foregroundColor: AppColors.ink,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.manrope(
        color: AppColors.ink,
        fontSize: 18,
        fontWeight: FontWeight.w800,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.brand,
        foregroundColor: AppColors.onBrand,
        disabledBackgroundColor: AppColors.surface2,
        disabledForegroundColor: AppColors.muted,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 16),
        textStyle: GoogleFonts.manrope(
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink,
        padding: const EdgeInsets.symmetric(vertical: 15),
        textStyle: GoogleFonts.manrope(
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
        side: const BorderSide(color: AppColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.brand,
        textStyle: GoogleFonts.manrope(
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface2,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: const TextStyle(color: AppColors.muted),
      hintStyle: const TextStyle(color: AppColors.muted),
      prefixIconColor: AppColors.muted,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.brand, width: 1.5),
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      surfaceTintColor: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: AppColors.line),
      ),
      margin: EdgeInsets.zero,
    ),
    dividerTheme: const DividerThemeData(color: AppColors.line, thickness: 1),
    dialogTheme: const DialogThemeData(backgroundColor: AppColors.surface),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: AppColors.surface,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.brand,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          color: s.contains(WidgetState.selected)
              ? AppColors.onBrand
              : AppColors.muted,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => GoogleFonts.manrope(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: s.contains(WidgetState.selected)
              ? AppColors.ink
              : AppColors.muted,
        ),
      ),
      height: 68,
    ),
  );
}

/// Reusable coloured avatar with the person's initial — replaces the
/// generic child icon for a cleaner, photo-like look.
class InitialAvatar extends StatelessWidget {
  final String name;
  final double radius;
  const InitialAvatar(this.name, {super.key, this.radius = 22});

  static const _palette = [
    Color(0xFFFFB020),
    Color(0xFF4C8DFF),
    Color(0xFF37C978),
    Color(0xFFB06AF5),
    Color(0xFFFF7A59),
    Color(0xFF23C4C4),
  ];

  @override
  Widget build(BuildContext context) {
    final letter = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    final color = _palette[name.hashCode.abs() % _palette.length];
    return CircleAvatar(
      radius: radius,
      backgroundColor: color.withValues(alpha: 0.16),
      child: Text(
        letter,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: radius * 0.85,
        ),
      ),
    );
  }
}
