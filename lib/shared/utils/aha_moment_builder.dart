import 'package:flutter/foundation.dart';

import 'financial_action_engine.dart';
import 'financial_insight_engine.dart';

/// CONSUMER MONETIZATION FOUNDATION — PHASE 3. A pure Dart, deterministic
/// selector over the ALREADY-computed [FinancialActionPlan.actions]/
/// [FinancialInsightResult.insights] — never a new financial calculation,
/// never AI-generated. Picks which already-ranked action/insight best fits
/// each of the three "Aha Moment" slots (risk/opportunity/doing well) plus
/// the single "next best move" recommendation.
@immutable
class AhaMomentResult {
  const AhaMomentResult({
    required this.riskTitle,
    required this.riskExplanation,
    required this.opportunityTitle,
    required this.opportunityExplanation,
    required this.doingWellTitle,
    required this.doingWellExplanation,
    required this.nextBestMoveTitle,
    required this.nextBestMoveAction,
    required this.hasSufficientData,
  });

  final String? riskTitle;
  final String? riskExplanation;
  final String? opportunityTitle;
  final String? opportunityExplanation;
  final String? doingWellTitle;
  final String? doingWellExplanation;

  /// The ONE deterministic recommendation — never AI-generated. The AI may
  /// explain it later, but never invents or recomputes it.
  final String? nextBestMoveTitle;
  final String? nextBestMoveAction;

  /// False only when neither engine surfaced anything at all (e.g. a
  /// brand-new empty account) — the UI should show an honest empty state
  /// rather than three blank cards.
  final bool hasSufficientData;
}

T? _firstWhere<T>(Iterable<T> items, bool Function(T) test) {
  for (final item in items) {
    if (test(item)) return item;
  }
  return null;
}

class AhaMomentBuilder {
  AhaMomentBuilder._();

  static AhaMomentResult build({
    required List<FinancialAction> actions,
    required List<FinancialInsight> insights,
  }) {
    final riskAction = _firstWhere(
      actions,
      (a) => a.priority == ActionPriority.critical || a.priority == ActionPriority.high,
    );
    final riskInsight = riskAction != null
        ? null
        : _firstWhere(
            insights,
            (i) => i.priority == InsightPriority.critical || i.priority == InsightPriority.high,
          );

    final opportunityAction = _firstWhere(
      actions,
      (a) => a.priority == ActionPriority.medium && a != riskAction,
    );
    final opportunityInsight = opportunityAction != null
        ? null
        : _firstWhere(
            insights,
            (i) => (i.priority == InsightPriority.medium || i.priority == InsightPriority.low) && i != riskInsight,
          );

    final doingWellAction = _firstWhere(actions, (a) => a.priority == ActionPriority.positive);
    final doingWellInsight = doingWellAction != null
        ? null
        : _firstWhere(insights, (i) => i.priority == InsightPriority.positive);

    final nextMove = riskAction ?? (actions.isNotEmpty ? actions.first : null);

    final hasSufficientData = riskAction != null ||
        riskInsight != null ||
        opportunityAction != null ||
        opportunityInsight != null ||
        doingWellAction != null ||
        doingWellInsight != null;

    return AhaMomentResult(
      riskTitle: riskAction?.title ?? riskInsight?.title,
      riskExplanation: riskAction?.explanation ?? riskInsight?.explanation,
      opportunityTitle: opportunityAction?.title ?? opportunityInsight?.title,
      opportunityExplanation: opportunityAction?.explanation ?? opportunityInsight?.explanation,
      doingWellTitle: doingWellAction?.title ?? doingWellInsight?.title,
      doingWellExplanation: doingWellAction?.explanation ?? doingWellInsight?.explanation,
      nextBestMoveTitle: nextMove?.title,
      nextBestMoveAction: nextMove?.recommendedAction,
      hasSufficientData: hasSufficientData,
    );
  }
}
