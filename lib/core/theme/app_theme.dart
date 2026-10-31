import 'package:flutter/material.dart';

import 'tokens.dart';

final _chipShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.circular(AppRadii.chip),
);

/// Dark only until Phase 9 adds the light variant.
ThemeData appTheme() => ThemeData(
  brightness: Brightness.dark,
  colorScheme: const ColorScheme.dark(
    primary: AppColors.accent,
    onPrimary: AppColors.bg,
    secondary: AppColors.accent,
    onSecondary: AppColors.bg,
    // These default to the light accent: white progress tracks, dark chip labels.
    primaryContainer: AppColors.surfaceRaised,
    onPrimaryContainer: AppColors.textPrimary,
    secondaryContainer: AppColors.surfaceRaised,
    onSecondaryContainer: AppColors.textPrimary,
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
    onSurfaceVariant: AppColors.textSecondary,
  ),
  scaffoldBackgroundColor: AppColors.bg,
  canvasColor: AppColors.surface,
  textTheme: const TextTheme(
    displayLarge: TextStyle(
      fontSize: 56,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
    ),
    displaySmall: TextStyle(
      fontSize: 34,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
    ),
    bodyLarge: TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w500,
      letterSpacing: 0,
      color: AppColors.textPrimary,
    ),
    bodySmall: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      color: AppColors.textSecondary,
    ),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    scrolledUnderElevation: 0,
    centerTitle: true,
  ),
  cardTheme: CardThemeData(
    color: AppColors.surface,
    elevation: 0,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.card),
    ),
  ),
  chipTheme: ChipThemeData(
    backgroundColor: AppColors.surface,
    selectedColor: AppColors.surfaceRaised,
    side: BorderSide.none,
    shape: _chipShape,
    showCheckmark: false,
  ),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: AppColors.accent,
    foregroundColor: AppColors.bg,
    shape: CircleBorder(),
  ),
  bottomSheetTheme: const BottomSheetThemeData(
    backgroundColor: AppColors.surface,
    modalBackgroundColor: AppColors.surface,
    surfaceTintColor: Colors.transparent,
    showDragHandle: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.card)),
    ),
  ),
  listTileTheme: const ListTileThemeData(
    subtitleTextStyle: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w400,
      color: AppColors.textSecondary,
    ),
  ),
  dividerTheme: const DividerThemeData(
    color: AppColors.surfaceRaised,
    space: 1,
    thickness: 1,
  ),
  snackBarTheme: const SnackBarThemeData(
    // Floating sits above the page's FAB, and so above the pill nav too.
    behavior: SnackBarBehavior.floating,
  ),
);
