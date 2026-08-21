// Focused dark-mode checks for the Tax Planner screen and the chat
// _TaxOutcomeCard (PHASE 18/33) — every new color combination this
// milestone introduces, on top of the ones already locked in by
// dark_mode_contrast_test.dart / ai_screen_dark_mode_test.dart. No new
// tokens are introduced — this only verifies the specific pairings the Tax
// Planner screen actually renders.
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

  test('33a. the validation-error message (danger text) is readable on the page background', () {
    AppColors.currentBrightness = Brightness.dark;
    expect(_contrastRatio(AppColors.danger, AppColors.background), greaterThanOrEqualTo(3.0));
  });

  test('33b. the irregular-income warning note is readable on its card surface', () {
    AppColors.currentBrightness = Brightness.dark;
    expect(_contrastRatio(AppColors.warning, AppColors.surface), greaterThanOrEqualTo(3.0));
  });

  test('33c. a disabled deduction field label is still legible against the input background', () {
    AppColors.currentBrightness = Brightness.dark;
    expect(_contrastRatio(AppColors.disabledText, AppColors.inputBackground), greaterThanOrEqualTo(2.0));
  });

  test('33d. the empty-state banner text is readable on surfaceVariant', () {
    AppColors.currentBrightness = Brightness.dark;
    expect(_contrastRatio(AppColors.textSecondary, AppColors.surfaceVariant), greaterThanOrEqualTo(3.0));
  });

  test('33e. the regime comparison figures (bold textPrimary) are readable on the card surface', () {
    AppColors.currentBrightness = Brightness.dark;
    expect(_contrastRatio(AppColors.textPrimary, AppColors.surface), greaterThanOrEqualTo(4.5));
  });

  test('33f. the tax-card icon chip tint stays a translucent overlay, not a solid patch', () {
    AppColors.currentBrightness = Brightness.dark;
    expect(AppColors.lightTeal.a, greaterThan(0.0));
    expect(AppColors.lightTeal.a, lessThan(1.0));
    expect(_contrastRatio(AppColors.primary, AppColors.surface), greaterThanOrEqualTo(2.5));
  });

  test('light theme is unaffected — Tax Planner colors still resolve correctly in light mode', () {
    AppColors.currentBrightness = Brightness.light;
    expect(_contrastRatio(AppColors.danger, AppColors.background), greaterThanOrEqualTo(3.0));
    expect(_contrastRatio(AppColors.textPrimary, AppColors.surface), greaterThanOrEqualTo(4.5));
  });
}
