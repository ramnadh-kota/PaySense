import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  /// Primary Deep Teal — dominant PaySense brand color.
  static const Color primary = Color(0xFF0B4F4A);

  /// Primary Dark Teal — deeper brand shade for dark-theme surfaces and
  /// pressed/emphasis states.
  static const Color primaryDark = Color(0xFF073B3A);

  /// A mid-toned teal derived from [primary], used where a second distinct
  /// (but still visible) shade is needed — e.g. chart/preset color cycles —
  /// without reaching for the accent.
  static const Color secondary = Color(0xFF608D89);

  /// Accent Coral Orange — used sparingly for high-attention CTAs and
  /// engagement moments (Add Expense/Income, Pay EMI, milestones, AI
  /// highlights). Never the dominant surface color.
  static const Color accent = Color(0xFFE05A3F);

  /// Pale teal tint for selected/highlighted backgrounds.
  static const Color lightTeal = Color(0xFFDDF3F0);

  /// Pale coral tint for milestone/achievement highlight backgrounds.
  static const Color softCoral = Color(0xFFFCE5DF);

  static const Color background = Color(0xFFF7F9F8);
  static const Color surface = Colors.white;

  static const Color success = Color(0xFF1F8A70);
  static const Color danger = Color(0xFFD64545);
  static const Color warning = Color(0xFFD99A2B);

  static const Color textPrimary = Color(0xFF1F2933);
  static const Color textSecondary = Color(0xFF667085);

  static const Color divider = Color(0xFFE5E7EB);
}