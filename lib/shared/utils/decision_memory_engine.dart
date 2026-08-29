import 'package:flutter/foundation.dart';

import '../models/decision_memory_record.dart';

/// Classification of the historical pattern detected by [DecisionMemoryEngine].
enum DecisionMemoryPatternType {
  /// Fewer than [DecisionMemoryEngine.minHistoryForPattern] records exist.
  insufficientHistory,

  /// User frequently cancelled/waited when considering similar purchases.
  frequentlyWaited,

  /// User frequently proceeded with similar purchases.
  frequentlyProceeded,

  /// User has a balanced mix of proceeding and waiting on similar purchases.
  mixedHistory,

  /// High frequency of decision evaluations in this category recently.
  repeatedCategoryPressure,
}

/// Structured, deterministic insight summarizing historical decision context.
/// Purely additive context — never overrides authoritative financial math.
@immutable
class DecisionMemoryInsight {
  const DecisionMemoryInsight({
    required this.type,
    required this.headline,
    required this.supportingMessage,
    required this.similarDecisionCount,
    required this.proceededCount,
    required this.cancelledCount,
    required this.categoryId,
    required this.hasSufficientHistory,
    required this.recentDecisionsCount,
  });

  /// High-level pattern category.
  final DecisionMemoryPatternType type;

  /// Concise summary title (e.g. "Previous decisions on Dining").
  final String headline;

  /// Respectful, non-judgmental explanation.
  final String supportingMessage;

  /// Count of historical decisions in the same category within amount tolerance.
  final int similarDecisionCount;

  /// How many similar decisions the user proceeded with.
  final int proceededCount;

  /// How many similar decisions the user chose to cancel / wait on.
  final int cancelledCount;

  /// The target category evaluated.
  final String categoryId;

  /// True when at least [DecisionMemoryEngine.minHistoryForPattern] similar records exist.
  final bool hasSufficientHistory;

  /// Total count of decisions recorded across all categories in the recent lookback window.
  final int recentDecisionsCount;

  /// Convenience helper: true if user previously cancelled at least once.
  bool get hasPastWaitedDecisions => cancelledCount > 0;

  /// Convenience helper: true if user previously proceeded at least once.
  bool get hasPastProceededDecisions => proceededCount > 0;
}

/// Pure Dart, deterministic engine for analyzing historical decision memory.
/// Zero side effects, zero network/AI dependency.
class DecisionMemoryEngine {
  DecisionMemoryEngine._();

  static const double defaultAmountTolerancePercent = 30.0;
  static const int minHistoryForPattern = 2;
  static const int recentLookbackDays = 30;

  /// Evaluates historical decisions against a prospective expense.
  static DecisionMemoryInsight analyze({
    required double amount,
    required String categoryId,
    required List<DecisionMemoryRecord> history,
    DateTime? now,
    double amountTolerancePercent = defaultAmountTolerancePercent,
  }) {
    final referenceNow = now ?? DateTime.now();
    final normalizedCategory = categoryId.trim().toLowerCase();
    final lookbackStart = referenceNow.subtract(
      const Duration(days: recentLookbackDays),
    );

    // Filter recent history within lookback window
    final recentHistory = history.where((r) {
      return !r.timestamp.isBefore(lookbackStart) &&
          !r.timestamp.isAfter(referenceNow);
    }).toList();

    // Category matches (case-insensitive)
    final categoryDecisions = recentHistory.where((r) {
      return r.categoryId.trim().toLowerCase() == normalizedCategory;
    }).toList();

    // Amount proximity matches
    final safeTolerance =
        amountTolerancePercent.clamp(0.0, 500.0) / 100.0; // as fraction
    final minAmount = amount > 0 ? amount * (1.0 - safeTolerance) : 0.0;
    final maxAmount = amount > 0 ? amount * (1.0 + safeTolerance) : double.infinity;

    final similarDecisions = categoryDecisions.where((r) {
      if (amount <= 0) return true;
      return r.amount >= minAmount && r.amount <= maxAmount;
    }).toList();

    final similarCount = similarDecisions.length;
    final proceededCount =
        similarDecisions.where((r) => r.wasProceeded).length;
    final cancelledCount =
        similarDecisions.where((r) => r.wasCancelled).length;

    final categoryCount = categoryDecisions.length;

    // Case 1: Insufficient history
    if (similarCount < minHistoryForPattern && categoryCount < 3) {
      return DecisionMemoryInsight(
        type: DecisionMemoryPatternType.insufficientHistory,
        headline: 'First time evaluating $categoryId',
        supportingMessage:
            'PaySense will remember your decision to help provide future context.',
        similarDecisionCount: similarCount,
        proceededCount: proceededCount,
        cancelledCount: cancelledCount,
        categoryId: categoryId,
        hasSufficientHistory: false,
        recentDecisionsCount: recentHistory.length,
      );
    }

    // Case 2: Specific similar decisions pattern
    if (similarCount >= minHistoryForPattern) {
      if (cancelledCount > proceededCount) {
        return DecisionMemoryInsight(
          type: DecisionMemoryPatternType.frequentlyWaited,
          headline: 'Previous $categoryId decisions',
          supportingMessage:
              "You've evaluated $similarCount similar purchases recently and chose to wait on $cancelledCount of them.",
          similarDecisionCount: similarCount,
          proceededCount: proceededCount,
          cancelledCount: cancelledCount,
          categoryId: categoryId,
          hasSufficientHistory: true,
          recentDecisionsCount: recentHistory.length,
        );
      } else if (proceededCount > cancelledCount) {
        return DecisionMemoryInsight(
          type: DecisionMemoryPatternType.frequentlyProceeded,
          headline: 'Previous $categoryId decisions',
          supportingMessage:
              "You've evaluated $similarCount similar purchases recently and proceeded with $proceededCount of them.",
          similarDecisionCount: similarCount,
          proceededCount: proceededCount,
          cancelledCount: cancelledCount,
          categoryId: categoryId,
          hasSufficientHistory: true,
          recentDecisionsCount: recentHistory.length,
        );
      } else {
        return DecisionMemoryInsight(
          type: DecisionMemoryPatternType.mixedHistory,
          headline: 'Previous $categoryId decisions',
          supportingMessage:
              "You've evaluated $similarCount similar purchases recently (proceeded with $proceededCount, waited on $cancelledCount).",
          similarDecisionCount: similarCount,
          proceededCount: proceededCount,
          cancelledCount: cancelledCount,
          categoryId: categoryId,
          hasSufficientHistory: true,
          recentDecisionsCount: recentHistory.length,
        );
      }
    }

    // Case 3: Repeated category activity across different amounts
    return DecisionMemoryInsight(
      type: DecisionMemoryPatternType.repeatedCategoryPressure,
      headline: 'Frequent $categoryId activity',
      supportingMessage:
          "You've made $categoryCount decision evaluations in $categoryId over the last 30 days.",
      similarDecisionCount: similarCount,
      proceededCount: proceededCount,
      cancelledCount: cancelledCount,
      categoryId: categoryId,
      hasSufficientHistory: true,
      recentDecisionsCount: recentHistory.length,
    );
  }
}
