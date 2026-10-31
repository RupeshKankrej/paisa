import 'package:flutter/material.dart';

import 'tokens.dart';

final _chipShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.circular(AppRadii.chip),
);

ThemeData appTheme([Brightness brightness = Brightness.dark]) {
  final dark = brightness == Brightness.dark;
  final p = dark ? AppPalette.dark : AppPalette.light;
  return _build(
    brightness,
    p,
    dark ? const ColorScheme.dark() : const ColorScheme.light(),
  );
}

ThemeData _build(Brightness brightness, AppPalette p, ColorScheme base) =>
    ThemeData(
      brightness: brightness,
      extensions: [p],
      colorScheme: base.copyWith(
        primary: p.accent,
        onPrimary: p.bg,
        secondary: p.accent,
        onSecondary: p.bg,
        // These default to the light accent: white progress tracks, dark chip labels.
        primaryContainer: p.surfaceRaised,
        onPrimaryContainer: p.textPrimary,
        secondaryContainer: p.surfaceRaised,
        onSecondaryContainer: p.textPrimary,
        surface: p.surface,
        onSurface: p.textPrimary,
        onSurfaceVariant: p.textSecondary,
      ),
      scaffoldBackgroundColor: p.bg,
      canvasColor: p.surface,
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontSize: 56,
          fontWeight: FontWeight.w700,
          color: p.textPrimary,
        ),
        displaySmall: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w700,
          color: p.textPrimary,
        ),
        bodyLarge: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w500,
          letterSpacing: 0,
          color: p.textPrimary,
        ),
        bodySmall: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          letterSpacing: 0,
          color: p.textSecondary,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.surface,
        selectedColor: p.surfaceRaised,
        side: BorderSide.none,
        shape: _chipShape,
        showCheckmark: false,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.accent,
        foregroundColor: p.bg,
        shape: const CircleBorder(),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        modalBackgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.card),
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        subtitleTextStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: p.textSecondary,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: p.surfaceRaised,
        space: 1,
        thickness: 1,
      ),
      snackBarTheme: const SnackBarThemeData(
        // Floating sits above the page's FAB, and so above the pill nav too.
        behavior: SnackBarBehavior.floating,
      ),
    );
