import 'package:flutter/material.dart';

/// Design tokens from SPEC 5.12 that change with the theme. Category colours
/// live in the database seed.
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.bg,
    required this.heroTop,
    required this.surface,
    required this.surfaceRaised,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
  });

  static const dark = AppPalette(
    bg: Color(0xFF121619),
    heroTop: Color(0xFF1E3A4C),
    surface: Color(0xFF1C2227),
    surfaceRaised: Color(0xFF262D33),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFF8A949C),
    accent: Color(0xFFF2F2F2),
  );

  static const light = AppPalette(
    bg: Color(0xFFF3F5F7),
    heroTop: Color(0xFFC9DFED),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFE4E8EC),
    textPrimary: Color(0xFF12171B),
    textSecondary: Color(0xFF5C6770),
    accent: Color(0xFF1C2227),
  );

  final Color bg;

  /// Top of the Activity header, fading down to [bg].
  final Color heroTop;
  final Color surface;
  final Color surfaceRaised;
  final Color textPrimary;
  final Color textSecondary;
  final Color accent;

  @override
  AppPalette copyWith() => this;

  @override
  AppPalette lerp(AppPalette? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      bg: mix(bg, other.bg),
      heroTop: mix(heroTop, other.heroTop),
      surface: mix(surface, other.surface),
      surfaceRaised: mix(surfaceRaised, other.surfaceRaised),
      textPrimary: mix(textPrimary, other.textPrimary),
      textSecondary: mix(textSecondary, other.textSecondary),
      accent: mix(accent, other.accent),
    );
  }
}

extension PaletteOf on BuildContext {
  /// Dark when a test's bare MaterialApp has no palette.
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.dark;
}

/// Colours that are the same in both themes.
abstract final class AppColors {
  static const income = Color(0xFF4CC38A);
  static const expense = Color(0xFF5AA9F5);

  /// Debit amounts in lists: SPEC 5.2 keeps them red-ish.
  static const debit = Color(0xFFE8737A);

  /// Swipe-delete action and destructive buttons (references 24, 25).
  static const delete = Color(0xFFCB5550);
}

abstract final class AppRadii {
  static const card = 20.0;

  /// Activity's day cards and their icon tiles (references 01, 02).
  static const dayCard = 28.0;
  static const iconTile = 10.0;
  static const chip = 16.0;
  static const round = 999.0;
}
