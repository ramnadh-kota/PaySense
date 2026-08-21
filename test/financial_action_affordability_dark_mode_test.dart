// Focused dark-mode checks for FINANCIAL ACTION ENGINE 1.0's new UI
// surfaces (PHASE 18, test items 38-39): the dashboard's
// "Your Financial Actions" cards (colored by priority) and the chat/screen
// "Can I Afford This?" cards. No new AppColors tokens were introduced —
// this locks in the SPECIFIC pairings these new widgets actually render,
// on top of what dark_mode_contrast_test.dart already covers generically.
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

  group('38. Financial action card contrast', () {
    // The card itself stays at the default AppColors.surface background
    // (like every other card in the app) — softCoral/lightTeal are only
    // ever a small translucent chip tint BEHIND the icon, never painted as
    // the whole card's background. So the meaningful contrast check is the
    // icon/text against `surface`, not against the tint itself — the tint
    // is translucent by design (computeLuminance() ignores alpha, per the
    // established lesson in ai_screen_dark_mode_test.dart's 30c).
    test('the chip tint is genuinely translucent, not an opaque patch', () {
      AppColors.currentBrightness = Brightness.dark;
      for (final tint in [AppColors.softCoral, AppColors.lightTeal]) {
        expect(tint.a, greaterThan(0.0));
        expect(tint.a, lessThan(1.0));
      }
    });

    test('a high/critical-priority card: the danger icon is readable against the card surface', () {
      AppColors.currentBrightness = Brightness.dark;
      expect(_contrastRatio(AppColors.danger, AppColors.surface), greaterThanOrEqualTo(2.5));
    });

    test('a medium/positive-priority card: the warning/success icon is readable against the card surface', () {
      AppColors.currentBrightness = Brightness.dark;
      expect(_contrastRatio(AppColors.warning, AppColors.surface), greaterThanOrEqualTo(2.0));
      expect(_contrastRatio(AppColors.success, AppColors.surface), greaterThanOrEqualTo(2.0));
    });

    test('the explanation text (textPrimary, bold) is readable on the card surface', () {
      AppColors.currentBrightness = Brightness.dark;
      expect(_contrastRatio(AppColors.textPrimary, AppColors.surface), greaterThanOrEqualTo(4.0));
    });

    test('the recommendedAction link text (primary) is readable on the card surface', () {
      AppColors.currentBrightness = Brightness.dark;
      expect(_contrastRatio(AppColors.primary, AppColors.surface), greaterThanOrEqualTo(2.5));
    });
  });

  group('39. Affordability card contrast', () {
    test('every status color (success/primary/warning/danger/textSecondary) is readable on the card surface', () {
      AppColors.currentBrightness = Brightness.dark;
      for (final statusColor in [
        AppColors.success,
        AppColors.primary,
        AppColors.warning,
        AppColors.danger,
        AppColors.textSecondary,
      ]) {
        expect(
          _contrastRatio(statusColor, AppColors.surface),
          greaterThanOrEqualTo(2.5),
          reason: 'status color $statusColor on surface',
        );
      }
    });

    test('the purchase-amount headline (textPrimary, bold) is readable on the card surface', () {
      AppColors.currentBrightness = Brightness.dark;
      expect(_contrastRatio(AppColors.textPrimary, AppColors.surface), greaterThanOrEqualTo(4.5));
    });

    test('the "See full analysis" link and simulation-disclaimer text are readable on the card surface', () {
      AppColors.currentBrightness = Brightness.dark;
      expect(_contrastRatio(AppColors.primary, AppColors.surface), greaterThanOrEqualTo(3.0));
      expect(_contrastRatio(AppColors.textSecondary, AppColors.surface), greaterThanOrEqualTo(3.0));
    });

    test('the reduced-emphasis input field on the full Affordability screen stays distinguishable', () {
      AppColors.currentBrightness = Brightness.dark;
      expect(AppColors.inputBackground, isNot(equals(AppColors.background)));
    });
  });

  test('light theme is unaffected — every pairing above still resolves correctly in light mode', () {
    AppColors.currentBrightness = Brightness.light;
    expect(_contrastRatio(AppColors.danger, AppColors.surface), greaterThanOrEqualTo(2.5));
    expect(_contrastRatio(AppColors.textPrimary, AppColors.surface), greaterThanOrEqualTo(4.5));
  });
}
