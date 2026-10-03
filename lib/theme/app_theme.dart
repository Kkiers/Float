import 'package:flutter/material.dart';

class AppTheme {
  static const _seed = Color(0xFFE8A838);

  // Orb-specific palette
  static const orbCore = Color(0xFFE8A838);
  static const orbGlow = Color(0xFFF0C060);
  static const orbSurfaceGlass = Color(0xFF1C1C1E);
  static const orbTextOnGlass = Color(0xFFF2F2F7);
  static const orbIconHighlight = Color(0xFFFFD580);

  // 月经周期模块色板（中性、无粉红小花、高对比）
  static const cycleBackground = Color(0xFFFDFBF9); // 暖白底
  static const cycleRose = Color(0xFFFF5A7D); // 已记录经期
  static const cycleRoseOutline = Color(0x66FF5A7D); // 预测空心（40%）
  static const cycleRoseFill = Color(0x1AFF5A7D); // 预测软填充（10%）
  static const cycleAccent = Color(0xFF5C80E5); // 今日/强调
  static const cycleTextNavy = Color(0xFF20132E); // 主文字
  static const cycleSymptom = Color(0xFF9C6ADE); // 时间线症状紫点
  static const cycleSymptomGray = Color(0xFFB0AAB8); // 日历症状灰点

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
