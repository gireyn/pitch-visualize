import 'package:flutter/material.dart';

abstract final class AppColors {
  static const background = Color(0xff101419);
  static const surface = Color(0xff191f27);
  static const raised = Color(0xff232c36);
  static const ink = Color(0xfff1f4f7);
  static const muted = Color(0xffa7b5c5);
  static const accent = Color(0xff8de0cb);
  static const line = Color(0xff35404d);
}

ThemeData buildTheme() => ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: AppColors.background,
  colorScheme: const ColorScheme.dark(
    primary: AppColors.accent,
    onPrimary: Color(0xff102b24),
    surface: AppColors.surface,
    onSurface: AppColors.ink,
    secondary: Color(0xffffd75e),
    outline: AppColors.line,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.background,
    foregroundColor: AppColors.ink,
    centerTitle: false,
    elevation: 0,
  ),
  dividerTheme: const DividerThemeData(color: AppColors.line, space: 1),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(48, 52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(48, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  ),
  iconButtonTheme: IconButtonThemeData(
    style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
  ),
  sliderTheme: const SliderThemeData(
    showValueIndicator: ShowValueIndicator.onlyForContinuous,
  ),
);
