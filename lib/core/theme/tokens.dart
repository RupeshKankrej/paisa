import 'dart:ui';

/// Design tokens from SPEC 5.12. Category colours live in the database seed.
abstract final class AppColors {
  static const bg = Color(0xFF121619);
  static const surface = Color(0xFF1C2227);
  static const surfaceRaised = Color(0xFF262D33);
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFF8A949C);
  static const accent = Color(0xFFF2F2F2);
  static const income = Color(0xFF4CC38A);
  static const expense = Color(0xFF5AA9F5);

  /// Debit amounts in lists: SPEC 5.2 keeps them red-ish.
  static const debit = Color(0xFFE8737A);
}

abstract final class AppRadii {
  static const card = 20.0;
  static const chip = 16.0;
  static const round = 999.0;
}
