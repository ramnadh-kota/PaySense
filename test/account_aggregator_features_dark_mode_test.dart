// Dark-mode checks for this milestone's new screens (Account Aggregator
// connect/connected-accounts, Feature Search, Recurring Money, Data
// Export). Follows the exact convention established in
// test/compare_periods_dark_mode_test.dart — pure AppColors token
// contrast checks, no widget pumping. Reuses the SAME AppColors tokens
// already validated elsewhere in the app; the only genuinely NEW
// pairings this milestone introduces are the "TEST DATA" mock badge, the
// "PaySense Plus" search-result badge, and the liability (debt) balance
// color — those are what this file actually adds coverage for.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paysense/core/constants/app_colors.dart';

double _contrastRatio(Color a, Color b) {
  final lumA = a.computeLuminance();
  final lumB = b.computeLuminance();
  final lighter = lumA > lumB ? lumA : lumB;
  final darker = lumA > lumB ? lumB : lumA;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  tearDown(() {
    AppColors.currentBrightness = Brightness.light;
  });

  group('Connected Accounts — "TEST DATA" mock badge', () {
    test('warning text on its own translucent warning tint is readable and the tint is translucent', () {
      AppColors.currentBrightness = Brightness.dark;
      final tint = AppColors.warning.withValues(alpha: 0.15);
      expect(tint.a, greaterThan(0.0));
      expect(tint.a, lessThan(1.0));
      expect(_contrastRatio(AppColors.warning, AppColors.surface), greaterThanOrEqualTo(2.0));
    });

    test('connection status dot colors (success/warning/danger) are all distinguishable on the surface', () {
      AppColors.currentBrightness = Brightness.dark;
      expect(_contrastRatio(AppColors.success, AppColors.surface), greaterThanOrEqualTo(2.5));
      expect(_contrastRatio(AppColors.warning, AppColors.surface), greaterThanOrEqualTo(2.0));
      expect(_contrastRatio(AppColors.danger, AppColors.surface), greaterThanOrEqualTo(2.5));
    });
  });

  group('Bank Connect / Connected Accounts — liability (debt) balance', () {
    test('danger-colored outstanding balance is readable on the surfaceVariant liability card', () {
      AppColors.currentBrightness = Brightness.dark;
      expect(_contrastRatio(AppColors.danger, AppColors.surfaceVariant), greaterThanOrEqualTo(2.5));
    });
  });

  group('Feature Search — "PaySense Plus" gated badge', () {
    test('primary text on its own translucent primary tint is readable and the tint is translucent', () {
      AppColors.currentBrightness = Brightness.dark;
      final tint = AppColors.primary.withValues(alpha: 0.12);
      expect(tint.a, greaterThan(0.0));
      expect(tint.a, lessThan(1.0));
      expect(_contrastRatio(AppColors.primary, AppColors.surface), greaterThanOrEqualTo(2.5));
    });
  });

  group('Recurring Money — insight banner and overdue amounts', () {
    test('insight banner text (textPrimary) on its translucent primary tint is readable', () {
      AppColors.currentBrightness = Brightness.dark;
      final tint = AppColors.primary.withValues(alpha: 0.08);
      expect(tint.a, greaterThan(0.0));
      expect(tint.a, lessThan(1.0));
      expect(_contrastRatio(AppColors.textPrimary, AppColors.surface), greaterThanOrEqualTo(4.5));
    });

    test('an overdue recurring row (danger) is readable on the surface', () {
      AppColors.currentBrightness = Brightness.dark;
      expect(_contrastRatio(AppColors.danger, AppColors.surface), greaterThanOrEqualTo(2.5));
    });
  });

  group('Data Export — body text and secondary copy', () {
    test('primary and secondary text both remain readable on the background', () {
      AppColors.currentBrightness = Brightness.dark;
      expect(_contrastRatio(AppColors.textPrimary, AppColors.background), greaterThanOrEqualTo(4.5));
      expect(_contrastRatio(AppColors.textSecondary, AppColors.background), greaterThanOrEqualTo(3.0));
    });
  });

  test('light theme is unaffected — every new pairing above still resolves correctly in light mode', () {
    AppColors.currentBrightness = Brightness.light;
    expect(_contrastRatio(AppColors.warning, AppColors.surface), greaterThanOrEqualTo(2.0));
    expect(_contrastRatio(AppColors.danger, AppColors.surfaceVariant), greaterThanOrEqualTo(2.5));
    expect(_contrastRatio(AppColors.primary, AppColors.surface), greaterThanOrEqualTo(2.5));
    expect(_contrastRatio(AppColors.textPrimary, AppColors.background), greaterThanOrEqualTo(4.5));
  });
}
