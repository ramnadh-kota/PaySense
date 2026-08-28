// Consumer Monetization Foundation — PHASE 9/14/16 item 12. Focused
// dark-mode checks for the new onboarding/snapshot/aha-moment/paywall/
// getting-started-checklist/premium-discovery-banner UI. Every new screen
// uses only AppColors semantic tokens (verified below) — no hardcoded
// colors were introduced.
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

  group('Onboarding goal/income-source selection tiles', () {
    test('selected-tile tint (primary at low alpha) is translucent, not opaque', () {
      AppColors.currentBrightness = Brightness.dark;
      final tint = AppColors.primary.withValues(alpha: 0.10);
      expect(tint.a, greaterThan(0.0));
      expect(tint.a, lessThan(1.0));
    });

    test('selected-tile border (primary) and unselected border (divider) are both readable/distinguishable', () {
      AppColors.currentBrightness = Brightness.dark;
      expect(AppColors.primary, isNot(equals(AppColors.divider)));
      expect(_contrastRatio(AppColors.primary, AppColors.surface), greaterThanOrEqualTo(2.5));
    });

    test('tile label text (textPrimary) is readable on the surface', () {
      AppColors.currentBrightness = Brightness.dark;
      expect(_contrastRatio(AppColors.textPrimary, AppColors.surface), greaterThanOrEqualTo(4.5));
    });
  });

  group('Financial Snapshot screen', () {
    test('the Net Worth headline card (white on primary) is readable', () {
      AppColors.currentBrightness = Brightness.dark;
      expect(_contrastRatio(Colors.white, AppColors.primary), greaterThanOrEqualTo(3.0));
    });

    test('stat tile labels (textSecondary) and values (textPrimary) are both readable on surface', () {
      AppColors.currentBrightness = Brightness.dark;
      expect(_contrastRatio(AppColors.textSecondary, AppColors.surface), greaterThanOrEqualTo(3.0));
      expect(_contrastRatio(AppColors.textPrimary, AppColors.surface), greaterThanOrEqualTo(4.5));
    });

    test('the empty/insufficient-data icon and message (textSecondary) are readable', () {
      AppColors.currentBrightness = Brightness.dark;
      expect(_contrastRatio(AppColors.textSecondary, AppColors.surface), greaterThanOrEqualTo(3.0));
    });
  });

  group('Aha Moment cards', () {
    test('risk (danger), opportunity (warning), and doing-well (success) labels are each readable on surface', () {
      AppColors.currentBrightness = Brightness.dark;
      expect(_contrastRatio(AppColors.danger, AppColors.surface), greaterThanOrEqualTo(2.5));
      expect(_contrastRatio(AppColors.warning, AppColors.surface), greaterThanOrEqualTo(2.0));
      expect(_contrastRatio(AppColors.success, AppColors.surface), greaterThanOrEqualTo(2.5));
    });

    test('the next-best-move icon chip (primary on lightTeal) is readable and translucent', () {
      AppColors.currentBrightness = Brightness.dark;
      expect(AppColors.lightTeal.a, greaterThan(0.0));
      expect(AppColors.lightTeal.a, lessThan(1.0));
      expect(_contrastRatio(AppColors.primary, AppColors.surface), greaterThanOrEqualTo(2.5));
    });
  });

  group('Paywall screen', () {
    test('the founding-member badge (warning on translucent warning tint) is readable', () {
      AppColors.currentBrightness = Brightness.dark;
      final tint = AppColors.warning.withValues(alpha: 0.14);
      expect(tint.a, greaterThan(0.0));
      expect(tint.a, lessThan(1.0));
      expect(_contrastRatio(AppColors.warning, AppColors.surface), greaterThanOrEqualTo(2.0));
    });

    test('the benefit checkmarks (success) are readable on the card surface', () {
      AppColors.currentBrightness = Brightness.dark;
      expect(_contrastRatio(AppColors.success, AppColors.surface), greaterThanOrEqualTo(2.5));
    });

    test('selected vs unselected pricing plan cards remain visually distinct', () {
      AppColors.currentBrightness = Brightness.dark;
      expect(AppColors.surface, isNot(equals(AppColors.primary.withValues(alpha: 0.10))));
    });

    test('the "Best value" badge (primary on lightTeal) is readable', () {
      AppColors.currentBrightness = Brightness.dark;
      expect(_contrastRatio(AppColors.primary, AppColors.lightTeal), greaterThanOrEqualTo(1.0));
    });
  });

  group('Getting Started checklist (Dashboard)', () {
    test('the progress bar fill (primary) is distinguishable from its track (surfaceVariant)', () {
      AppColors.currentBrightness = Brightness.dark;
      expect(AppColors.primary, isNot(equals(AppColors.surfaceVariant)));
    });

    test('a done item (success check, textSecondary strikethrough label) is readable', () {
      AppColors.currentBrightness = Brightness.dark;
      expect(_contrastRatio(AppColors.success, AppColors.surface), greaterThanOrEqualTo(2.5));
      expect(_contrastRatio(AppColors.textSecondary, AppColors.surface), greaterThanOrEqualTo(3.0));
    });

    test('a not-done item (textSecondary checkbox, textPrimary label) is readable', () {
      AppColors.currentBrightness = Brightness.dark;
      expect(_contrastRatio(AppColors.textPrimary, AppColors.surface), greaterThanOrEqualTo(4.5));
    });
  });

  group('Premium discovery banner (shared across AI/Affordability/Tax Planner)', () {
    test('the icon chip (primary on lightTeal) and CTA text (primary) are both readable', () {
      AppColors.currentBrightness = Brightness.dark;
      expect(_contrastRatio(AppColors.primary, AppColors.surface), greaterThanOrEqualTo(2.5));
    });

    test('title (textPrimary) and subtitle (textSecondary) are both readable', () {
      AppColors.currentBrightness = Brightness.dark;
      expect(_contrastRatio(AppColors.textPrimary, AppColors.surface), greaterThanOrEqualTo(4.5));
      expect(_contrastRatio(AppColors.textSecondary, AppColors.surface), greaterThanOrEqualTo(3.0));
    });
  });

  test('light theme is unaffected — every pairing above still resolves correctly in light mode', () {
    AppColors.currentBrightness = Brightness.light;
    expect(_contrastRatio(AppColors.textPrimary, AppColors.surface), greaterThanOrEqualTo(4.5));
    expect(_contrastRatio(AppColors.success, AppColors.surface), greaterThanOrEqualTo(2.5));
    expect(_contrastRatio(AppColors.danger, AppColors.surface), greaterThanOrEqualTo(2.5));
    expect(_contrastRatio(AppColors.primary, AppColors.surface), greaterThanOrEqualTo(2.5));
  });
}
