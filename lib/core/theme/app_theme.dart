import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'app_typography.dart';

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.background,
    primaryColor: AppColors.primary,
    textTheme: AppTypography.textTheme,
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary).copyWith(
      primary: AppColors.primary,
      secondary: AppColors.accent,
      onSecondary: Colors.white,
      error: AppColors.danger,
      onError: Colors.white,
      surface: AppColors.surface,
    ),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      centerTitle: false,
      backgroundColor: Colors.transparent,
      foregroundColor: AppColors.textPrimary,
    ),
  );

  /// A deliberate dark variant — not an inversion of [lightTheme]. Deep Teal
  /// (via [AppColors.primaryDark]) anchors dark-mode brand surfaces, Coral
  /// Orange stays the accent, and neutral surfaces are dark charcoal rather
  /// than a generic gray. Note that most PaySense screens paint with the
  /// [AppColors] constants directly (not `Theme.of(context)`), so this
  /// affects default Material chrome (dialogs, switches, text selection,
  /// etc.) rather than a full app-wide re-skin — see Settings feature notes.
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF12201F),
    primaryColor: AppColors.primary,
    textTheme: AppTypography.textTheme.apply(
      bodyColor: Colors.white,
      displayColor: Colors.white,
    ),
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primaryDark,
      brightness: Brightness.dark,
      surface: const Color(0xFF1B2B2A),
    ).copyWith(
      primary: AppColors.primary,
      secondary: AppColors.accent,
      onSecondary: Colors.white,
      error: AppColors.danger,
      onError: Colors.white,
    ),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      centerTitle: false,
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
    ),
    cardColor: const Color(0xFF1B2B2A),
    dividerColor: const Color(0xFF2E3F3E),
  );
}