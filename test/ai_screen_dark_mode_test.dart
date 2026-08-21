// Focused dark-mode rendering basics for the AI screen (PHASE 14) — the AI
// screen introduces no new colors of its own, it only consumes the shared
// AppColors tokens (already verified brightness-reactive/contrast-checked
// in dark_mode_contrast_test.dart from the P0 sprint). This locks in that
// every token the AI screen's new widgets (message bubbles, the Financial
// Planning card, the typing indicator, the empty-data banner, the input
// field) actually use stays readable in dark mode specifically.
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

  test('30a. user message bubble (white text on primary) is readable in dark mode', () {
    AppColors.currentBrightness = Brightness.dark;
    expect(_contrastRatio(Colors.white, AppColors.primary), greaterThanOrEqualTo(3.0));
  });

  test('30b. assistant message bubble text is readable on its surface in dark mode', () {
    AppColors.currentBrightness = Brightness.dark;
    expect(_contrastRatio(AppColors.textPrimary, AppColors.surface), greaterThanOrEqualTo(4.5));
  });

  test('30c. Financial Planning card icon tint is a translucent overlay, not a solid patch', () {
    AppColors.currentBrightness = Brightness.dark;
    // In dark mode lightTeal is `primary.withValues(alpha: 0.18)` — a
    // translucent tint meant to blend with whatever surface it sits on
    // (Color.computeLuminance() ignores alpha, so a raw contrast-ratio
    // comparison against its own base color is meaningless here). What
    // actually matters: it's genuinely translucent (not opaque, not fully
    // transparent), and the icon drawn on top of it (AppColors.primary) is
    // independently readable against the card surface it's nested in.
    expect(AppColors.lightTeal.a, greaterThan(0.0));
    expect(AppColors.lightTeal.a, lessThan(1.0));
    expect(_contrastRatio(AppColors.primary, AppColors.surface), greaterThanOrEqualTo(2.5));
  });

  test('30d. the chat input field fill is distinguishable from the page background', () {
    AppColors.currentBrightness = Brightness.dark;
    expect(AppColors.inputBackground, isNot(equals(AppColors.background)));
  });

  test('30e. the "Thinking..." typing indicator text is readable in dark mode', () {
    AppColors.currentBrightness = Brightness.dark;
    expect(_contrastRatio(AppColors.textSecondary, AppColors.surface), greaterThanOrEqualTo(3.0));
  });

  test('30f. the empty-data banner text is readable on its surfaceVariant background', () {
    AppColors.currentBrightness = Brightness.dark;
    expect(_contrastRatio(AppColors.textSecondary, AppColors.surfaceVariant), greaterThanOrEqualTo(3.0));
  });

  test('light theme is unaffected — AI screen colors still resolve correctly in light mode', () {
    AppColors.currentBrightness = Brightness.light;
    expect(_contrastRatio(AppColors.textPrimary, AppColors.surface), greaterThanOrEqualTo(4.5));
    expect(_contrastRatio(Colors.white, AppColors.primary), greaterThanOrEqualTo(3.0));
  });
}
