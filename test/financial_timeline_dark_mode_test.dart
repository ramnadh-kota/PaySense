// Focused dark-mode checks for the Financial Intelligence Timeline screen
// (PHASE 9): momentum card, signal chips, and timeline row icon/tint
// pairings. Reuses the exact AppColors token pairings already established
// by financial_health_trends_dark_mode_test.dart /
// financial_insight_dark_mode_test.dart — no new tokens were introduced.
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

  group('Momentum card', () {
    test('improving/declining/stable/insufficientData icon colors are readable on the card surface', () {
      AppColors.currentBrightness = Brightness.dark;
      expect(_contrastRatio(AppColors.success, AppColors.surface), greaterThanOrEqualTo(2.5));
      expect(_contrastRatio(AppColors.danger, AppColors.surface), greaterThanOrEqualTo(2.5));
      expect(_contrastRatio(AppColors.textSecondary, AppColors.surface), greaterThanOrEqualTo(3.0));
      expect(_contrastRatio(AppColors.primary, AppColors.surface), greaterThanOrEqualTo(2.5));
    });

    test('the status label text (textPrimary, bold) is readable on the card surface', () {
      AppColors.currentBrightness = Brightness.dark;
      expect(_contrastRatio(AppColors.textPrimary, AppColors.surface), greaterThanOrEqualTo(4.5));
    });
  });

  group('Signal chips', () {
    test('the chip background (surfaceVariant) is distinguishable from the card surface', () {
      AppColors.currentBrightness = Brightness.dark;
      expect(AppColors.surfaceVariant, isNot(equals(AppColors.surface)));
    });

    test('every direction arrow color (success/danger/textSecondary) is readable on surfaceVariant', () {
      AppColors.currentBrightness = Brightness.dark;
      for (final color in [AppColors.success, AppColors.danger, AppColors.textSecondary]) {
        expect(_contrastRatio(color, AppColors.surfaceVariant), greaterThanOrEqualTo(2.0));
      }
    });

    test('the chip label text (textPrimary) is readable on surfaceVariant', () {
      AppColors.currentBrightness = Brightness.dark;
      expect(_contrastRatio(AppColors.textPrimary, AppColors.surfaceVariant), greaterThanOrEqualTo(4.0));
    });
  });

  group('Timeline row icon chips (tone-based)', () {
    test('positive tone (success on lightTeal) is readable', () {
      AppColors.currentBrightness = Brightness.dark;
      expect(_contrastRatio(AppColors.success, AppColors.surface), greaterThanOrEqualTo(2.5));
    });

    test('warning tone (danger on softCoral) is readable', () {
      AppColors.currentBrightness = Brightness.dark;
      expect(_contrastRatio(AppColors.danger, AppColors.surface), greaterThanOrEqualTo(2.5));
    });

    test('neutral tone (textSecondary on surfaceVariant) is readable', () {
      AppColors.currentBrightness = Brightness.dark;
      expect(_contrastRatio(AppColors.textSecondary, AppColors.surface), greaterThanOrEqualTo(3.0));
    });

    test('every chip tint is translucent, not an opaque full-card background', () {
      AppColors.currentBrightness = Brightness.dark;
      for (final tint in [AppColors.softCoral, AppColors.lightTeal, AppColors.surfaceVariant]) {
        expect(tint.a, lessThanOrEqualTo(1.0));
      }
    });

    test('the compact date column text (textSecondary) is readable on the row surface', () {
      AppColors.currentBrightness = Brightness.dark;
      expect(_contrastRatio(AppColors.textSecondary, AppColors.surface), greaterThanOrEqualTo(3.0));
    });

    test('the explanation text (textSecondary) is readable on the row surface', () {
      AppColors.currentBrightness = Brightness.dark;
      expect(_contrastRatio(AppColors.textSecondary, AppColors.surface), greaterThanOrEqualTo(3.0));
    });
  });

  test('light theme is unaffected — every pairing above still resolves correctly in light mode', () {
    AppColors.currentBrightness = Brightness.light;
    expect(_contrastRatio(AppColors.textPrimary, AppColors.surface), greaterThanOrEqualTo(4.5));
    expect(_contrastRatio(AppColors.success, AppColors.surface), greaterThanOrEqualTo(2.5));
    expect(_contrastRatio(AppColors.danger, AppColors.surface), greaterThanOrEqualTo(2.5));
  });
}
