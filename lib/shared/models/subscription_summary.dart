import 'package:flutter/foundation.dart';

/// Whether a derived subscription's next renewal has already passed.
enum SubscriptionStatus { active, overdue }

/// A derived, in-memory view of an existing [RecurringTransaction] for the
/// Subscription Manager feature.
///
/// This is NOT a persisted model and is never written to Hive — it is
/// always computed on the fly from `RecurringTransaction` data by
/// `SubscriptionCalculator`. Every field here traces back to an existing
/// `RecurringTransaction` field (or a calculation over it); nothing is
/// invented.
@immutable
class SubscriptionSummary {
  const SubscriptionSummary({
    required this.id,
    required this.name,
    required this.amount,
    required this.frequency,
    required this.nextDueDate,
    required this.category,
    required this.account,
    required this.monthlyEquivalent,
    required this.annualCost,
    required this.status,
    required this.sourceId,
  });

  /// Same value as [sourceId] — the originating RecurringTransaction's id.
  final String id;

  /// From [RecurringTransaction.title].
  final String name;

  /// From [RecurringTransaction.amount] — the per-occurrence amount, not a
  /// monthly/annual figure.
  final double amount;

  /// From [RecurringTransaction.frequency] ('Daily'/'Weekly'/'Monthly'/'Yearly').
  final String frequency;

  /// From [RecurringTransaction.nextDueDate].
  final DateTime nextDueDate;

  /// From [RecurringTransaction.categoryId], trimmed. Empty string means no
  /// category was recorded — callers should display this as "Uncategorized"
  /// rather than fabricating a category.
  final String category;

  /// From [RecurringTransaction.accountId].
  final String account;

  /// This subscription's cost normalized to a monthly figure:
  /// `annualCost / 12`.
  final double monthlyEquivalent;

  /// This subscription's cost annualized from [amount] and [frequency].
  final double annualCost;

  /// [SubscriptionStatus.overdue] when [nextDueDate] has already passed.
  final SubscriptionStatus status;

  /// The originating RecurringTransaction's id — used for navigation back
  /// to the existing recurring edit flow and for duplicate protection.
  final String sourceId;

  bool get isOverdue => status == SubscriptionStatus.overdue;
}
