import 'package:flutter/material.dart';

ThemeData appTheme(Brightness brightness) => ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF00695C),
    brightness: brightness,
  ),
);
