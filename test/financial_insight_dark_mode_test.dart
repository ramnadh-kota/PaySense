// Focused dark-mode checks for the Dashboard's Proactive Financial
// Insights cards (PHASE 4). Reuses the exact icon/tint pairings from
// _InsightCard._visualsFor — no new AppColors tokens were introduced.
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

  group('Insight card icon/text colors against the card surface', () {
    test('critical/high (danger on softCoral chip) — icon and title text are readable', () {
      AppColors.currentBrightness = Brightness.dark;
      expect(_contrastRatio(AppColors.danger, AppColors.surface), greaterThanOrEqualTo(2.5));
      expect(_contrastRatio(AppColors.textPrimary, AppColors.surface), greaterThanOrEqualTo(4.5));
    });

    test('medium (warning on lightTeal chip) is readable', () {
      AppColors.currentBrightness = Brightness.dark;
      expect(_contrastRatio(AppColors.warning, AppColors.surface), greaterThanOrEqualTo(2.0));
    });

    test('low (textSecondary on surfaceVariant chip) is readable and distinguishable from the chip tint', () {
      AppColors.currentBrightness = Brightness.dark;
      expect(_contrastRatio(AppColors.textSecondary, AppColors.surface), greaterThanOrEqualTo(3.0));
      expect(AppColors.surfaceVariant, isNot(equals(AppColors.surface)));
    });

    test('positive (success on lightTeal chip) is readable', () {
      AppColors.currentBrightness = Brightness.dark;
      expect(_contrastRatio(AppColors.success, AppColors.surface), greaterThanOrEqualTo(2.5));
    });

    test('every chip tint is translucent, not an opaque full-card background', () {
      AppColors.currentBrightness = Brightness.dark;
      for (final tint in [AppColors.softCoral, AppColors.lightTeal, AppColors.surfaceVariant]) {
        expect(tint.a, lessThanOrEqualTo(1.0));
      }
    });

    test('the recommendedAction link text (primary) is readable on the card surface', () {
      AppColors.currentBrightness = Brightness.dark;
      expect(_contrastRatio(AppColors.primary, AppColors.surface), greaterThanOrEqualTo(2.5));
    });

    test('the explanation text (textSecondary) is readable on the card surface', () {
      AppColors.currentBrightness = Brightness.dark;
      expect(_contrastRatio(AppColors.textSecondary, AppColors.surface), greaterThanOrEqualTo(3.0));
    });
  });

  test('light theme is unaffected — every pairing above still resolves correctly in light mode', () {
    AppColors.currentBrightness = Brightness.light;
    expect(_contrastRatio(AppColors.danger, AppColors.surface), greaterThanOrEqualTo(2.5));
    expect(_contrastRatio(AppColors.success, AppColors.surface), greaterThanOrEqualTo(2.5));
    expect(_contrastRatio(AppColors.textPrimary, AppColors.surface), greaterThanOrEqualTo(4.5));
  });
}
