import 'package:flutter/material.dart';

class AppTheme {
  static const _seed = Color(0xFFE8A838);

  // Orb-specific palette
  static const orbCore = Color(0xFFE8A838);
  static const orbGlow = Color(0xFFF0C060);
  static const orbSurfaceGlass = Color(0xFF1C1C1E);
  static const orbTextOnGlass = Color(0xFFF2F2F7);
  static const orbIconHighlight = Color(0xFFFFD580);

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.light,
    );
    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFF7F5F0),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFFF7F5F0),
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        centerTitle: false,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  static ThemeData overlay() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: orbCore,
        surface: orbSurfaceGlass,
        onSurface: orbTextOnGlass,
      ),
      scaffoldBackgroundColor: Colors.transparent,
    );
  }
}
