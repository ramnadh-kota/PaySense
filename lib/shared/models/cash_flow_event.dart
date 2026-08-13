import 'package:flutter/foundation.dart';

/// The kind of financial event a [CashFlowEvent] represents.
enum CashFlowEventType {
  income,
  expense,
  bill,
  recurringPayment,
  recurringIncome,
  loanPayment,
}

/// A single derived, in-memory calendar entry for the Cash Flow feature.
///
/// This is NOT a persisted model — it is always computed on the fly from
/// existing [Transaction]/[Bill]/[Loan]/[RecurringTransaction] data by
/// `CashFlowCalculator`. Never stored in Hive.
@immutable
class CashFlowEvent {
  const CashFlowEvent({
    required this.date,
    required this.amount,
    required this.type,
    required this.title,
    required this.source,
    required this.isUpcoming,
    required this.isOverdue,
    this.sourceId,
  });

  /// Calendar day this event falls on (time-of-day stripped).
  final DateTime date;

  final double amount;

  final CashFlowEventType type;

  final String title;

  /// Human-readable origin label, e.g. 'Transaction', 'Bill', 'Loan EMI',
  /// 'Recurring Payment', 'Recurring Income' — used for grouping/subtitles.
  final String source;

  /// True for a not-yet-occurred obligation (unpaid bill, active loan's
  /// next EMI, active recurring item's next occurrence). False for a
  /// recorded [Transaction] — those already happened.
  final bool isUpcoming;

  /// True when an upcoming obligation's due date has already passed.
  /// Always false for recorded transactions and non-overdue upcoming items.
  final bool isOverdue;

  /// Id of the originating Bill/Loan/RecurringTransaction/Transaction, for
  /// navigating to its detail screen. Null when there is none to link to.
  final String? sourceId;

  /// True for money coming in (income or recurring income).
  bool get isInflow =>
      type == CashFlowEventType.income ||
      type == CashFlowEventType.recurringIncome;
}
