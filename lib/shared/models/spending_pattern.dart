import 'package:flutter/foundation.dart';

/// Phase 6E Step 7 — Spending Pattern Types
///
/// Deterministic classification of recurring spending behaviors and decision habits.
enum SpendingPatternType {
  /// A specific category appears with unusually high frequency.
  frequentCategory,

  /// A specific merchant or payee appears repeatedly.
  repeatedMerchant,

  /// Category spending is trending higher compared to the prior comparable period.
  increasingCategory,

  /// Category spending is heavily concentrated on weekend days.
  weekendHeavy,

  /// High frequency of small discretionary transactions accumulating meaningfully.
  smallPurchaseFrequency,

  /// Repeated purchase evaluations in Decision Memory (e.g., frequently paused or proceeded).
  repeatedDecisionPattern,

  /// A category with steady, predictable, and stable spending.
  stableCategory,

  /// When not enough transaction history exists yet to compute reliable patterns.
  insufficientHistory,
}

/// An immutable, non-judgmental spending pattern insight.
@immutable
class SpendingPattern {
  const SpendingPattern({
    required this.type,
    required this.title,
    required this.description,
    this.categoryId,
    this.merchantName,
    this.occurrenceCount,
    this.percentageChange,
    this.supportingValue,
    this.period,
    this.priority = 5,
  });

  /// High-level pattern category.
  final SpendingPatternType type;

  /// Concise title (e.g., "Dining appears frequently").
  final String title;

  /// Respectful, non-judgmental narrative explanation.
  final String description;

  /// Associated category identifier, if category-specific.
  final String? categoryId;

  /// Associated merchant name, if merchant-specific.
  final String? merchantName;

  /// Number of times the pattern was observed in the lookback window.
  final int? occurrenceCount;

  /// Percentage delta if comparing across periods (e.g., +24.5%).
  final double? percentageChange;

  /// Contextual amount or value in INR (e.g., total spent on small items).
  final double? supportingValue;

  /// Descriptive period label (e.g., "last 30 days").
  final String? period;

  /// Ranking priority for dashboard sorting (higher = shown earlier, 1-10).
  final int priority;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SpendingPattern &&
        other.type == type &&
        other.title == title &&
        other.description == description &&
        other.categoryId == categoryId &&
        other.merchantName == merchantName &&
        other.occurrenceCount == occurrenceCount &&
        other.percentageChange == percentageChange &&
        other.supportingValue == supportingValue &&
        other.period == period &&
        other.priority == priority;
  }

  @override
  int get hashCode => Object.hash(
        type,
        title,
        description,
        categoryId,
        merchantName,
        occurrenceCount,
        percentageChange,
        supportingValue,
        period,
        priority,
      );
}
