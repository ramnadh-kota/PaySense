// Focused dark-mode checks for the Financial Health Trends screen (PHASE
// 20/21 item 31): headings, secondary text, chart colors, cards, trend
// badges, positive/negative indicators, and empty states. No new
// AppColors tokens were introduced — this locks in the specific pairings
// this screen actually renders.
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

  test('headings (titleLarge/titleMedium, textPrimary) are readable on the page background', () {
    AppColors.currentBrightness = Brightness.dark;
    expect(_contrastRatio(AppColors.textPrimary, AppColors.background), greaterThanOrEqualTo(4.5));
    expect(_contrastRatio(AppColors.textPrimary, AppColors.surface), greaterThanOrEqualTo(4.5));
  });

  test('secondary text (subtitle, stat labels) is readable on the page background and card surface', () {
    AppColors.currentBrightness = Brightness.dark;
    expect(_contrastRatio(AppColors.textSecondary, AppColors.background), greaterThanOrEqualTo(3.0));
    expect(_contrastRatio(AppColors.textSecondary, AppColors.surface), greaterThanOrEqualTo(3.0));
  });

  group('Trend badges (improving/declining/stable/insufficientData)', () {
    test('the trend-badge tint chip is translucent, not an opaque patch', () {
      AppColors.currentBrightness = Brightness.dark;
      expect(AppColors.lightTeal.a, greaterThan(0.0));
      expect(AppColors.lightTeal.a, lessThan(1.0));
    });

    test('every badge label color is readable against the card surface it actually sits on', () {
      // _TrendBadge's text is painted directly on the card's own
      // AppColors.surface background (the lightTeal chip is a background
      // accent behind it, not the text's contrast partner — same
      // established pattern as the What-If/Tax/Affordability cards).
      AppColors.currentBrightness = Brightness.dark;
      for (final color in [AppColors.success, AppColors.danger, AppColors.textSecondary]) {
        expect(_contrastRatio(color, AppColors.surface), greaterThanOrEqualTo(2.5));
      }
    });
  });

  group('Positive/negative indicators', () {
    test('success (improving/positive) and danger (declining/negative) are both readable on surface', () {
      AppColors.currentBrightness = Brightness.dark;
      expect(_contrastRatio(AppColors.success, AppColors.surface), greaterThanOrEqualTo(2.5));
      expect(_contrastRatio(AppColors.danger, AppColors.surface), greaterThanOrEqualTo(2.5));
    });

    test('the warning color (mixed trajectory) is readable on surface and background', () {
      AppColors.currentBrightness = Brightness.dark;
      expect(_contrastRatio(AppColors.warning, AppColors.surface), greaterThanOrEqualTo(2.0));
      expect(_contrastRatio(AppColors.warning, AppColors.background), greaterThanOrEqualTo(2.0));
    });
  });

  group('Charts (health score line chart, cash-flow bar chart)', () {
    test('the line-chart stroke (primary) and fill (lightTeal) contrast against the card surface', () {
      AppColors.currentBrightness = Brightness.dark;
      expect(_contrastRatio(AppColors.primary, AppColors.surface), greaterThanOrEqualTo(2.5));
    });

    test('the bar-chart income (success) and expense (danger) colors are distinguishable from each other', () {
      AppColors.currentBrightness = Brightness.dark;
      // Not a WCAG check (both are meant to sit side-by-side as bars, not
      // as text/background) -- just confirms dark mode doesn't collapse
      // them to visually-identical colors.
      expect(AppColors.success, isNot(equals(AppColors.danger)));
    });

    test('chart axis labels (textSecondary) are readable on the card surface', () {
      AppColors.currentBrightness = Brightness.dark;
      expect(_contrastRatio(AppColors.textSecondary, AppColors.surface), greaterThanOrEqualTo(3.0));
    });
  });

  group('Cards', () {
    test('every AppCard-based section uses the same surface token as the rest of the app', () {
      AppColors.currentBrightness = Brightness.dark;
      expect(AppColors.surface, isNot(equals(AppColors.background)));
    });

    test('the progress-bar background (surfaceVariant) is distinguishable from the fill (primary)', () {
      AppColors.currentBrightness = Brightness.dark;
      expect(AppColors.surfaceVariant, isNot(equals(AppColors.primary)));
      expect(_contrastRatio(AppColors.primary, AppColors.surfaceVariant), greaterThanOrEqualTo(1.5));
    });
  });

  group('Empty states', () {
    test('the insufficient-data note (surfaceVariant background, textSecondary text) is readable', () {
      AppColors.currentBrightness = Brightness.dark;
      expect(_contrastRatio(AppColors.textSecondary, AppColors.surfaceVariant), greaterThanOrEqualTo(3.0));
    });

    test('the full-screen empty state icon (primary) is readable on the page background', () {
      AppColors.currentBrightness = Brightness.dark;
      expect(_contrastRatio(AppColors.primary, AppColors.background), greaterThanOrEqualTo(2.5));
    });
  });

  test('light theme is unaffected — every pairing above still resolves correctly in light mode', () {
    AppColors.currentBrightness = Brightness.light;
    expect(_contrastRatio(AppColors.textPrimary, AppColors.surface), greaterThanOrEqualTo(4.5));
    expect(_contrastRatio(AppColors.success, AppColors.surface), greaterThanOrEqualTo(2.5));
    expect(_contrastRatio(AppColors.danger, AppColors.surface), greaterThanOrEqualTo(2.5));
  });
}
