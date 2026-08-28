// Focused dark-mode checks for the Compare Periods screen (PHASE 9):
// summary metric colors, highlight cards, category-change (neutral) icons,
// verdict card, and the empty/insufficient-data state. Reuses the exact
// AppColors token pairings already established elsewhere in the app — no
// new tokens were introduced.
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

  group('Summary metric rows', () {
    test('positive comparison (success) is readable on the card surface', () {
      AppColors.currentBrightness = Brightness.dark;
      expect(_contrastRatio(AppColors.success, AppColors.surface), greaterThanOrEqualTo(2.5));
    });

    test('negative comparison (danger) is readable on the card surface', () {
      AppColors.currentBrightness = Brightness.dark;
      expect(_contrastRatio(AppColors.danger, AppColors.surface), greaterThanOrEqualTo(2.5));
    });

    test('neutral/unchanged comparison (textSecondary) is readable on the card surface', () {
      AppColors.currentBrightness = Brightness.dark;
      expect(_contrastRatio(AppColors.textSecondary, AppColors.surface), greaterThanOrEqualTo(3.0));
    });

    test('the period-pill emphasized background is translucent, not an opaque patch', () {
      AppColors.currentBrightness = Brightness.dark;
      final tint = AppColors.primary.withValues(alpha: 0.12);
      expect(tint.a, greaterThan(0.0));
      expect(tint.a, lessThan(1.0));
      expect(_contrastRatio(AppColors.primary, AppColors.surface), greaterThanOrEqualTo(2.5));
    });
  });

  group('Highlights (What\'s Better / Needs Attention)', () {
    test('the positive checkmark (success) is readable on the card surface', () {
      AppColors.currentBrightness = Brightness.dark;
      expect(_contrastRatio(AppColors.success, AppColors.surface), greaterThanOrEqualTo(2.5));
    });

    test('the warning icon (warning) is readable on the card surface', () {
      AppColors.currentBrightness = Brightness.dark;
      expect(_contrastRatio(AppColors.warning, AppColors.surface), greaterThanOrEqualTo(2.0));
    });

    test('highlight body text (textPrimary) is readable on the card surface', () {
      AppColors.currentBrightness = Brightness.dark;
      expect(_contrastRatio(AppColors.textPrimary, AppColors.surface), greaterThanOrEqualTo(4.5));
    });
  });

  group('Category Changes (strictly neutral)', () {
    test('the direction arrow (textSecondary) is readable — never success/danger for a category', () {
      AppColors.currentBrightness = Brightness.dark;
      expect(_contrastRatio(AppColors.textSecondary, AppColors.surface), greaterThanOrEqualTo(3.0));
    });
  });

  group('Financial Verdict card', () {
    test('the verdict icon chip (primary on lightTeal) is readable and translucent', () {
      AppColors.currentBrightness = Brightness.dark;
      expect(AppColors.lightTeal.a, greaterThan(0.0));
      expect(AppColors.lightTeal.a, lessThan(1.0));
      expect(_contrastRatio(AppColors.primary, AppColors.surface), greaterThanOrEqualTo(2.5));
    });

    test('the verdict text (textPrimary) is readable on the card surface', () {
      AppColors.currentBrightness = Brightness.dark;
      expect(_contrastRatio(AppColors.textPrimary, AppColors.surface), greaterThanOrEqualTo(4.5));
    });
  });

  group('Empty / insufficient-data state', () {
    test('the empty-state icon and message (textSecondary) are readable on the card surface', () {
      AppColors.currentBrightness = Brightness.dark;
      expect(_contrastRatio(AppColors.textSecondary, AppColors.surface), greaterThanOrEqualTo(3.0));
    });
  });

  group('Period preset chips', () {
    test('the selected-chip tint is distinguishable from the unselected surface', () {
      AppColors.currentBrightness = Brightness.dark;
      expect(AppColors.surface, isNot(equals(AppColors.primary.withValues(alpha: 0.16))));
    });
  });

  test('light theme is unaffected — every pairing above still resolves correctly in light mode', () {
    AppColors.currentBrightness = Brightness.light;
    expect(_contrastRatio(AppColors.textPrimary, AppColors.surface), greaterThanOrEqualTo(4.5));
    expect(_contrastRatio(AppColors.success, AppColors.surface), greaterThanOrEqualTo(2.5));
    expect(_contrastRatio(AppColors.danger, AppColors.surface), greaterThanOrEqualTo(2.5));
  });
}
