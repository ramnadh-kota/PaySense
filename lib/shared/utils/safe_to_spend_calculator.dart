import 'package:flutter/foundation.dart';

import '../models/bill.dart';
import '../models/loan.dart';
import '../models/recurring_transaction.dart';
import '../models/wallet.dart';

/// Default lookback/lookahead window for the Safe-to-Spend calculation.
/// Exposed as a constant (not a Settings preference) since there is no
/// existing user-configurable "planning window" concept to reuse, and
/// introducing one would be a new duplicated setting for a v1 feature.
const int safeToSpendWindowDays = 30;

enum SafeToSpendCommitmentType { bill, emi, recurring }

/// A single upcoming obligation included in the Safe-to-Spend calculation.
@immutable
class SafeToSpendCommitment {
  const SafeToSpendCommitment({
    required this.type,
    required this.title,
    required this.amount,
    required this.dueDate,
    required this.isOverdue,
  });

  final SafeToSpendCommitmentType type;
  final String title;
  final double amount;
  final DateTime dueDate;
  final bool isOverdue;
}

/// Result of a Safe-to-Spend calculation. Every field is derived directly
/// from existing PaySense data — nothing here is a fabricated/assumed value.
@immutable
class SafeToSpendResult {
  const SafeToSpendResult({
    required this.availableMoney,
    required this.upcomingCommitments,
    required this.plannedSavings,
    required this.savingsIncluded,
    required this.safeToSpend,
    required this.dailySafeToSpend,
    required this.remainingDays,
    required this.hasSufficientData,
    required this.shortfall,
    required this.commitmentBreakdown,
    required this.windowDays,
  });

  /// Sum of current balances across all of the user's wallets.
  final double availableMoney;

  /// Sum of [commitmentBreakdown] amounts.
  final double upcomingCommitments;

  /// Reserved for planned savings contributions. Always 0 today: the
  /// existing [Goal] model has no planned/monthly-contribution field, and
  /// this calculator deliberately never invents one (see [savingsIncluded]).
  final double plannedSavings;

  /// Whether [plannedSavings] reflects a real, data-backed reservation.
  /// False in the current app version — see [plannedSavings].
  final bool savingsIncluded;

  /// `max(0, availableMoney - upcomingCommitments - plannedSavings)`.
  final double safeToSpend;

  /// `safeToSpend / remainingDays`, or 0 when there is nothing safe to
  /// spend or the window has no days to spread it across.
  final double dailySafeToSpend;

  /// Number of days the calculation window covers (see [windowDays]) — the
  /// denominator used for [dailySafeToSpend]. Safe-to-Spend uses a fixed
  /// rolling window ("next N days from now"), not "days left in the
  /// calendar month", so this always equals [windowDays].
  final int remainingDays;

  /// False when there isn't enough data to produce a meaningful result
  /// (currently: no wallets at all) — callers should show a prompt to add
  /// account data instead of a fabricated ₹0.
  final bool hasSufficientData;

  /// How much upcoming commitments exceed available money by, or 0 when
  /// there is no shortfall. Mutually exclusive with a positive
  /// [safeToSpend]: at most one of the two is non-zero.
  final double shortfall;

  /// Every commitment counted toward [upcomingCommitments], soonest due
  /// first.
  final List<SafeToSpendCommitment> commitmentBreakdown;

  /// The lookahead window (in days) this result was computed for.
  final int windowDays;

  bool get isShortfall => shortfall > 0;
}

/// Pure, deterministic Safe-to-Spend calculation. No Flutter/Riverpod
/// dependency — reuses the existing Bill/Loan/RecurringTransaction models'
/// own `isOverdue`/`isUpcoming` due-date logic rather than re-deriving it,
/// so this stays consistent with how "upcoming" is defined everywhere else
/// in the app (just with a wider, explicit window).
class SafeToSpendCalculator {
  SafeToSpendCalculator._();

  static SafeToSpendResult calculate({
    required List<Wallet> wallets,
    required List<Bill> bills,
    required List<Loan> loans,
    required List<RecurringTransaction> recurringTransactions,
    required DateTime now,
    int windowDays = safeToSpendWindowDays,
  }) {
    if (wallets.isEmpty) {
      return SafeToSpendResult(
        availableMoney: 0,
        upcomingCommitments: 0,
        plannedSavings: 0,
        savingsIncluded: false,
        safeToSpend: 0,
        dailySafeToSpend: 0,
        remainingDays: windowDays,
        hasSufficientData: false,
        shortfall: 0,
        commitmentBreakdown: const [],
        windowDays: windowDays,
      );
    }

    final availableMoney = wallets.fold<double>(
      0,
      (sum, wallet) => sum + wallet.currentBalance,
    );

    final horizonStart = DateTime(now.year, now.month, now.day);
    final horizon = horizonStart.add(Duration(days: windowDays));

    final commitments = <SafeToSpendCommitment>[];

    // Bills: unpaid, and either already overdue or due within the window.
    // isOverdue/isUpcoming are mutually exclusive on the model itself
    // (isUpcoming returns false once isOverdue is true), so each bill is
    // added at most once.
    for (final bill in bills) {
      final overdue = bill.isOverdue(now);
      if (overdue || bill.isUpcoming(now, days: windowDays)) {
        commitments.add(
          SafeToSpendCommitment(
            type: SafeToSpendCommitmentType.bill,
            title: bill.title,
            amount: bill.amount,
            dueDate: bill.dueDate,
            isOverdue: overdue,
          ),
        );
      }
    }

    // Loan EMIs: active loans, same overdue/upcoming rule as bills.
    for (final loan in loans) {
      final overdue = loan.isOverdue(now);
      if (overdue || loan.isUpcoming(now, days: windowDays)) {
        commitments.add(
          SafeToSpendCommitment(
            type: SafeToSpendCommitmentType.emi,
            title: loan.loanName,
            amount: loan.emiAmount,
            dueDate: loan.nextDueDate,
            isOverdue: overdue,
          ),
        );
      }
    }

    // Recurring payments: active, non-expired, expense-type only — income
    // recurring items are money coming in, not a commitment to plan around.
    for (final item in recurringTransactions) {
      if (!item.isActive || item.isExpired) continue;
      if (item.transactionType.toLowerCase() != 'expense') continue;
      final overdue = item.nextDueDate.isBefore(horizonStart);
      if (overdue || !item.nextDueDate.isAfter(horizon)) {
        commitments.add(
          SafeToSpendCommitment(
            type: SafeToSpendCommitmentType.recurring,
            title: item.title,
            amount: item.amount,
            dueDate: item.nextDueDate,
            isOverdue: overdue,
          ),
        );
      }
    }

    commitments.sort((a, b) => a.dueDate.compareTo(b.dueDate));

    final upcomingCommitments = commitments.fold<double>(
      0,
      (sum, commitment) => sum + commitment.amount,
    );

    // Savings reservation intentionally omitted: Goal only stores a target
    // amount/date and a current balance, not a planned contribution rate,
    // so there is no reliable figure to reserve without guessing one.
    const plannedSavings = 0.0;
    const savingsIncluded = false;

    final rawSafeToSpend = availableMoney - upcomingCommitments - plannedSavings;
    final safeToSpend = rawSafeToSpend > 0 ? rawSafeToSpend : 0.0;
    final shortfall = rawSafeToSpend < 0 ? -rawSafeToSpend : 0.0;

    final dailySafeToSpend = (safeToSpend > 0 && windowDays > 0)
        ? safeToSpend / windowDays
        : 0.0;

    return SafeToSpendResult(
      availableMoney: availableMoney,
      upcomingCommitments: upcomingCommitments,
      plannedSavings: plannedSavings,
      savingsIncluded: savingsIncluded,
      safeToSpend: safeToSpend,
      dailySafeToSpend: dailySafeToSpend,
      remainingDays: windowDays,
      hasSufficientData: true,
      shortfall: shortfall,
      commitmentBreakdown: commitments,
      windowDays: windowDays,
    );
  }
}
