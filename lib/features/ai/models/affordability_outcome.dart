import 'package:flutter/foundation.dart';

import 'package:paysense/shared/utils/affordability_calculator.dart';

/// PHASE 6/7 — the outcome of resolving an [AffordabilityIntent] against
/// real financial data. Mirrors [WhatIfOutcome]/`TaxOutcome`'s shape.
enum AffordabilityOutcomeKind {
  /// A deterministic [AffordabilityResult] was produced.
  calculated,

  /// Recognized as an affordability question but missing the purchase
  /// amount — see [message].
  clarification,

  /// Not enough financial data exists to assess any purchase right now —
  /// see [message] (composed from [AffordabilityResult.recommendation] and
  /// [AffordabilityResult.reasons]).
  notFound,

  /// Not an affordability question (or not confidently one).
  none,
}

@immutable
class AffordabilityOutcome {
  const AffordabilityOutcome._({
    required this.kind,
    this.result,
    this.itemDescription,
    this.message,
  });

  factory AffordabilityOutcome.calculated(AffordabilityResult result, {String? itemDescription}) =>
      AffordabilityOutcome._(
        kind: AffordabilityOutcomeKind.calculated,
        result: result,
        itemDescription: itemDescription,
      );

  factory AffordabilityOutcome.clarification(String message) =>
      AffordabilityOutcome._(kind: AffordabilityOutcomeKind.clarification, message: message);

  factory AffordabilityOutcome.notFound(String message) =>
      AffordabilityOutcome._(kind: AffordabilityOutcomeKind.notFound, message: message);

  factory AffordabilityOutcome.none() => const AffordabilityOutcome._(kind: AffordabilityOutcomeKind.none);

  final AffordabilityOutcomeKind kind;
  final AffordabilityResult? result;
  final String? itemDescription;
  final String? message;
}
