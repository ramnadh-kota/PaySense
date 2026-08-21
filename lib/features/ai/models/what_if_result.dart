import 'package:flutter/foundation.dart';

import 'package:paysense/features/ai/services/what_if_intent_parser.dart' show WhatIfIntentType;

/// PHASE 10 — the structured result of a deterministic what-if calculation.
/// Every field here comes straight from an existing calculator
/// (`WhatIfCalculator`/`FinancialPlanningCalculator`) — this model never
/// stores the AI's prose, only the numbers/dates the AI is later asked to
/// explain (and must not contradict).
@immutable
class WhatIfResult {
  const WhatIfResult({
    required this.type,
    required this.currentValue,
    required this.projectedValue,
    required this.difference,
    required this.descriptionKey,
    this.monthsBefore,
    this.monthsAfter,
    this.completionDateBefore,
    this.completionDateAfter,
    this.monthlyChange,
    this.entityName,
  });

  final WhatIfIntentType type;

  /// The "before" figure most relevant to this scenario (e.g. current
  /// monthly savings, current outstanding loan balance).
  final double currentValue;

  /// The "after" figure under the hypothetical.
  final double projectedValue;

  /// `projectedValue - currentValue`.
  final double difference;

  final int? monthsBefore;
  final int? monthsAfter;
  final DateTime? completionDateBefore;
  final DateTime? completionDateAfter;

  /// The monthly amount that changed hands in this scenario (e.g. +₹5,000
  /// saved, -₹3,000 spent, +₹500 freed from a cancelled subscription).
  final double? monthlyChange;

  /// The real entity this scenario resolved to (loan/subscription/category/
  /// goal display name), for the chat card — never a guessed label.
  final String? entityName;

  /// Reuses [type]'s own name — a stable, non-prose key the AI/UI can key
  /// off of, never free-text.
  final String descriptionKey;

  /// Whether this scenario has a "months to reach" comparison worth
  /// showing (some scenarios, like a pure loan-payoff projection, don't).
  bool get hasTimeline => monthsBefore != null || monthsAfter != null;
}

/// PHASE 5/6/7/13 — the outcome of resolving a [WhatIfIntent] against real
/// financial data. Exactly one of [result]/[message] is populated,
/// depending on [kind].
enum WhatIfOutcomeKind {
  /// A deterministic calculation was produced — see [WhatIfOutcome.result].
  calculated,

  /// The intent was recognized but is missing information (an amount, or a
  /// choice between multiple matching entities) — see [WhatIfOutcome.message].
  clarification,

  /// The intent named an entity (category/loan/subscription/goal) that
  /// doesn't exist in the user's real data — see [WhatIfOutcome.message].
  notFound,

  /// Not a what-if scenario (or not confidently one) — callers must fall
  /// through to the normal AI flow unchanged.
  none,
}

@immutable
class WhatIfOutcome {
  const WhatIfOutcome._({required this.kind, this.result, this.message});

  factory WhatIfOutcome.calculated(WhatIfResult result) =>
      WhatIfOutcome._(kind: WhatIfOutcomeKind.calculated, result: result);

  factory WhatIfOutcome.clarification(String message) =>
      WhatIfOutcome._(kind: WhatIfOutcomeKind.clarification, message: message);

  factory WhatIfOutcome.notFound(String message) =>
      WhatIfOutcome._(kind: WhatIfOutcomeKind.notFound, message: message);

  factory WhatIfOutcome.none() => const WhatIfOutcome._(kind: WhatIfOutcomeKind.none);

  final WhatIfOutcomeKind kind;
  final WhatIfResult? result;
  final String? message;
}
