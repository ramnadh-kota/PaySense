import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  /// Primary Teal — official PaySense brand color.
  static const Color primary = Color(0xFF08393A);

  /// A lighter teal derived from [primary], used where a second distinct
  /// shade is needed (e.g. chart/preset color cycles) without reaching for
  /// the accent.
  static const Color secondary = Color(0xFF5E7E7F);

  /// Accent Orange — official PaySense brand color, for important
  /// secondary/accent actions and highlights.
  static const Color accent = Color(0xFFAB3A26);

  static const Color background = Color(0xFFF5F7FB);
  static const Color surface = Colors.white;

  static const Color success = Color(0xFF2ECC71);
  static const Color danger = Color(0xFFE74C3C);
  static const Color warning = Color(0xFFF39C12);

  /// Primary Charcoal — official PaySense brand color, used for body text.
  static const Color textPrimary = Color(0xFF343434);
  static const Color textSecondary = Color(0xFF9CA3AF);

  static const Color divider = Color(0xFFE5E7EB);
}