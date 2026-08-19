// Focused regression tests for the dark-mode visibility fix: AppColors'
// text/surface tokens are now brightness-reactive (see
// lib/core/constants/app_colors.dart), which is what actually makes
// Settings/Wallet/AI/Dashboard/etc. readable in dark mode, since every
// screen paints with `AppColors.x` directly rather than
// `Theme.of(context).colorScheme.x`. These tests assert real WCAG-style
// contrast between each foreground/background token pair in BOTH themes —
// the concrete, measurable form of "titles/labels/input fields must not be
// invisible" the manual tester reported.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paysense/core/constants/app_colors.dart';

/// WCAG 2.x relative-luminance contrast ratio, using Flutter's own
/// `Color.computeLuminance()` (the same relative-luminance formula the WCAG
/// spec defines). 4.5:1 is the WCAG AA threshold for normal body text;
/// 3.0:1 for large/bold text. Using 3.0 here as a floor that's still a
/// meaningful, deliberately-not-overly-strict regression guard, since some
/// of these pairs (e.g. tertiary/disabled text) are intentionally subdued.
double _contrastRatio(Color a, Color b) {
  final lumA = a.computeLuminance();
  final lumB = b.computeLuminance();
  final lighter = lumA > lumB ? lumA : lumB;
  final darker = lumA > lumB ? lumB : lumA;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  tearDown(() {
    // Every test must leave the global brightness switch back at its
    // default so it can't bleed into an unrelated test run afterward.
    AppColors.currentBrightness = Brightness.light;
  });

  group('19. Dark theme text contrast', () {
    test('primary text on background meets a readable contrast floor', () {
      AppColors.currentBrightness = Brightness.dark;
      expect(_contrastRatio(AppColors.textPrimary, AppColors.background), greaterThanOrEqualTo(4.5));
    });

    test('primary text on surface (cards) meets a readable contrast floor', () {
      AppColors.currentBrightness = Brightness.dark;
      expect(_contrastRatio(AppColors.textPrimary, AppColors.surface), greaterThanOrEqualTo(4.5));
    });

    test('secondary text on background/surface stays readable, not just present', () {
      AppColors.currentBrightness = Brightness.dark;
      expect(_contrastRatio(AppColors.textSecondary, AppColors.background), greaterThanOrEqualTo(3.0));
      expect(_contrastRatio(AppColors.textSecondary, AppColors.surface), greaterThanOrEqualTo(3.0));
    });

    test('dark-mode text is not simply reusing the light-mode (near-black) value', () {
      AppColors.currentBrightness = Brightness.light;
      final lightText = AppColors.textPrimary;
      AppColors.currentBrightness = Brightness.dark;
      final darkText = AppColors.textPrimary;
      expect(darkText, isNot(equals(lightText)));
    });
  });

  group('20. Dark theme input visibility', () {
    test('input fill is distinguishable from the page background', () {
      AppColors.currentBrightness = Brightness.dark;
      expect(AppColors.inputBackground, isNot(equals(AppColors.background)));
    });

    test('primary text on the input fill is readable', () {
      AppColors.currentBrightness = Brightness.dark;
      expect(_contrastRatio(AppColors.textPrimary, AppColors.inputBackground), greaterThanOrEqualTo(4.5));
    });
  });

  group('21. Dark theme Settings visibility', () {
    // Settings paints its tile labels/subtitles/section headers with
    // exactly these three tokens (see settings_screen.dart) — verifying the
    // tokens is a direct, non-fragile proxy for verifying the screen.
    test('section labels (textSecondary on background) are readable', () {
      AppColors.currentBrightness = Brightness.dark;
      expect(_contrastRatio(AppColors.textSecondary, AppColors.background), greaterThanOrEqualTo(3.0));
    });

    test('tile labels (textPrimary on surface) are readable', () {
      AppColors.currentBrightness = Brightness.dark;
      expect(_contrastRatio(AppColors.textPrimary, AppColors.surface), greaterThanOrEqualTo(4.5));
    });
  });

  group('22. Dark theme Wallet visibility', () {
    test('wallet name/balance (textPrimary on surface) is readable', () {
      AppColors.currentBrightness = Brightness.dark;
      expect(_contrastRatio(AppColors.textPrimary, AppColors.surface), greaterThanOrEqualTo(4.5));
    });

    test('bank name subtitle (textSecondary on surface) is readable', () {
      AppColors.currentBrightness = Brightness.dark;
      expect(_contrastRatio(AppColors.textSecondary, AppColors.surface), greaterThanOrEqualTo(3.0));
    });
  });

  group('23. Dark theme AI visibility', () {
    test('assistant message bubble text (textPrimary on surface) is readable', () {
      AppColors.currentBrightness = Brightness.dark;
      expect(_contrastRatio(AppColors.textPrimary, AppColors.surface), greaterThanOrEqualTo(4.5));
    });

    test('user message bubble text (white on primary) is readable', () {
      AppColors.currentBrightness = Brightness.dark;
      expect(_contrastRatio(Colors.white, AppColors.primary), greaterThanOrEqualTo(3.0));
    });

    test('"Hello, {name}" greeting (textPrimary on background) is readable', () {
      AppColors.currentBrightness = Brightness.dark;
      expect(_contrastRatio(AppColors.textPrimary, AppColors.background), greaterThanOrEqualTo(4.5));
    });
  });

  group('Light theme is unaffected by the dark-mode fix', () {
    test('light-mode contrast pairs still hold (no regression from the change)', () {
      AppColors.currentBrightness = Brightness.light;
      expect(_contrastRatio(AppColors.textPrimary, AppColors.background), greaterThanOrEqualTo(4.5));
      expect(_contrastRatio(AppColors.textPrimary, AppColors.surface), greaterThanOrEqualTo(4.5));
    });
  });
}
