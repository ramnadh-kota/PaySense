import 'package:flutter/material.dart';

/// Centralized color tokens for PaySense.
///
/// Most tokens are brightness-reactive getters (not `static const`) that
/// resolve against [currentBrightness]. Every screen in this app paints with
/// `AppColors.xxx` directly rather than `Theme.of(context).colorScheme.xxx`,
/// so making these getters theme-aware in this ONE place is what makes the
/// whole app dark-mode-correct, instead of requiring every screen to be
/// rewritten. [currentBrightness] is kept in sync by `PaySenseApp`'s
/// `MaterialApp.builder` on every build, which is also where the resolved
/// (system/light/dark) brightness is authoritatively known.
class AppColors {
  AppColors._();

  static Brightness currentBrightness = Brightness.light;
  static bool get _isDark => currentBrightness == Brightness.dark;

  /// Primary Deep Teal — dominant PaySense brand color. Brightened in dark
  /// mode (still teal, same hue family) since the light-mode shade is too
  /// dark to read as icon/text foreground color against a dark surface.
  static Color get primary =>
      _isDark ? const Color(0xFF2E8A82) : const Color(0xFF0B4F4A);

  /// Primary Dark Teal — deeper brand shade for dark-theme surfaces and
  /// pressed/emphasis states. Not brightness-reactive: it's always the deep
  /// anchor shade, used deliberately for dark-surface theming regardless of
  /// the active theme.
  static const Color primaryDark = Color(0xFF073B3A);

  /// A mid-toned teal derived from [primary], used where a second distinct
  /// (but still visible) shade is needed — e.g. chart/preset color cycles —
  /// without reaching for the accent.
  static const Color secondary = Color(0xFF608D89);

  /// Accent Coral Orange — used sparingly for high-attention CTAs and
  /// engagement moments (Add Expense/Income, Pay EMI, milestones, AI
  /// highlights). Never the dominant surface color. Already has enough
  /// contrast against both light and dark surfaces, so unlike [primary] it
  /// doesn't need a separate dark-mode shade.
  static const Color accent = Color(0xFFE05A3F);

  /// Pale teal tint for selected/highlighted backgrounds. In dark mode this
  /// becomes a translucent tint over the dark surface instead of a literal
  /// pale/near-white fill, which would otherwise look like a glaring patch.
  static Color get lightTeal =>
      _isDark ? primary.withValues(alpha: 0.18) : const Color(0xFFDDF3F0);

  /// Pale coral tint for milestone/achievement highlight backgrounds. Same
  /// dark-mode translucent-tint treatment as [lightTeal].
  static Color get softCoral =>
      _isDark ? accent.withValues(alpha: 0.2) : const Color(0xFFFCE5DF);

  static Color get background =>
      _isDark ? const Color(0xFF12201F) : const Color(0xFFF7F9F8);
  static Color get surface => _isDark ? const Color(0xFF1B2B2A) : Colors.white;

  /// A step above [surface] — for elements that need to stand out slightly
  /// from a card without being a full accent color (e.g. a nested row, a
  /// stat tile inside a card).
  static Color get surfaceVariant =>
      _isDark ? const Color(0xFF223635) : const Color(0xFFEEF1F0);

  /// Background fill for text fields / form inputs — distinct from
  /// [surface] so an input is visually identifiable as editable, in both
  /// themes.
  static Color get inputBackground =>
      _isDark ? const Color(0xFF223635) : const Color(0xFFF2F4F3);

  static Color get success =>
      _isDark ? const Color(0xFF2FAE8C) : const Color(0xFF1F8A70);
  static Color get danger =>
      _isDark ? const Color(0xFFF0685A) : const Color(0xFFD64545);
  static Color get warning =>
      _isDark ? const Color(0xFFE8B04A) : const Color(0xFFD99A2B);

  /// Semantic aliases for [success]/[danger] — same colors, named for call
  /// sites that talk about a value's sign (income vs expense, gain vs loss)
  /// rather than a status.
  static Color get positive => success;
  static Color get negative => danger;

  static Color get textPrimary =>
      _isDark ? const Color(0xFFF5F7F6) : const Color(0xFF1F2933);
  static Color get textSecondary =>
      _isDark ? const Color(0xFFAEB9B7) : const Color(0xFF667085);

  /// A third, dimmer text tier — timestamps, helper captions, placeholder
  /// text — one step quieter than [textSecondary].
  static Color get tertiaryText =>
      _isDark ? const Color(0xFF7C8B89) : const Color(0xFF98A2B3);

  /// For disabled controls/labels — deliberately low-contrast in both
  /// themes (that's the point), but never fully invisible.
  static Color get disabledText =>
      _isDark ? const Color(0xFF566361) : const Color(0xFFC1C7D0);

  /// Aliases matching the semantic-token names used elsewhere in the app's
  /// design vocabulary; identical values to [textPrimary]/[textSecondary].
  static Color get primaryText => textPrimary;
  static Color get secondaryText => textSecondary;

  static Color get border =>
      _isDark ? const Color(0xFF2E3F3E) : const Color(0xFFE5E7EB);

  /// Alias kept for existing call sites written before [border] existed.
  static Color get divider => border;
}
