import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'app_typography.dart';

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.background,
    primaryColor: AppColors.primary,
    textTheme: AppTypography.textTheme,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
    ),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      centerTitle: false,
      backgroundColor: Colors.transparent,
      foregroundColor: AppColors.textPrimary,
    ),
  );
}