import 'package:flutter/foundation.dart';

import 'package:paysense/shared/utils/tax_calculator.dart';

/// PHASE 10 — the outcome of resolving a [TaxIntent] against the user's
/// real (or estimated) tax data. Exactly one of [result]/[comparison]/
/// [message] is meaningfully populated, depending on [kind]. Mirrors
/// [WhatIfOutcome]'s shape/spirit but carries a full [TaxCalculationResult]
/// (or a before/after pair for a tax what-if) rather than a single
/// before/after figure — a tax scenario's structured result is genuinely
/// richer than a generic what-if's.
enum TaxOutcomeKind {
  /// A single deterministic calculation — see [result] (and [beforeResult]
  /// when this came from a tax what-if scenario).
  calculated,

  /// An old-vs-new regime comparison — see [comparison].
  comparison,

  /// Recognized as a tax question but missing information (an amount, or
  /// which regime to show) — see [message].
  clarification,

  /// No income data at all to calculate from — see [message].
  notFound,

  /// Not a tax question (or not confidently one) — fall through to the
  /// normal AI flow unchanged.
  none,
}

@immutable
class TaxOutcome {
  const TaxOutcome._({
    required this.kind,
    this.result,
    this.beforeResult,
    this.comparison,
    this.message,
    this.entityLabel,
  });

  factory TaxOutcome.calculated(TaxCalculationResult result, {TaxCalculationResult? beforeResult, String? entityLabel}) =>
      TaxOutcome._(
        kind: TaxOutcomeKind.calculated,
        result: result,
        beforeResult: beforeResult,
        entityLabel: entityLabel,
      );

  factory TaxOutcome.comparison(TaxRegimeComparisonResult comparison) =>
      TaxOutcome._(kind: TaxOutcomeKind.comparison, comparison: comparison);

  factory TaxOutcome.clarification(String message) =>
      TaxOutcome._(kind: TaxOutcomeKind.clarification, message: message);

  factory TaxOutcome.notFound(String message) =>
      TaxOutcome._(kind: TaxOutcomeKind.notFound, message: message);

  factory TaxOutcome.none() => const TaxOutcome._(kind: TaxOutcomeKind.none);

  final TaxOutcomeKind kind;
  final TaxCalculationResult? result;

  /// Only set for a tax what-if scenario (salary change / 80C / 80D /
  /// home-loan interest) — the baseline calculated BEFORE the hypothetical
  /// change, so the AI/UI can show a before/after comparison without
  /// recomputing anything itself.
  final TaxCalculationResult? beforeResult;

  final TaxRegimeComparisonResult? comparison;
  final String? message;

  /// A short display label for the what-if card, e.g. "Section 80C",
  /// "Home loan interest", "Salary change".
  final String? entityLabel;
}
