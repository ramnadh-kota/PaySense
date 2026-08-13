import 'package:flutter/foundation.dart';

import '../models/bill.dart';
import '../models/goal.dart';
import '../models/recurring_transaction.dart';
import '../models/transaction.dart';
import '../providers/loan_provider.dart' show LoanSummary;

/// Time-of-day greeting using the user's first name, with a safe fallback
/// when no profile name is set yet. Never hardcodes a name.
String greetingFor(DateTime now, String fullName) {
  final trimmed = fullName.trim();
  if (trimmed.isEmpty) {
    return 'Welcome back 👋';
  }

  final timeOfDay = now.hour < 12
      ? 'Morning'
      : now.hour < 17
      ? 'Afternoon'
      : 'Evening';
  final firstName = trimmed.split(' ').first;
  return 'Good $timeOfDay, $firstName 👋';
}

@immutable
class TodaysMoneySummary {
  const TodaysMoneySummary({
    required this.spent,
    required this.income,
    required this.hasActivity,
  });

  final double spent;
  final double income;
  final bool hasActivity;

  double get net => income - spent;
}

/// Sums today's (calendar day, based on [now]) expense/income transactions.
TodaysMoneySummary computeTodaysMoney(
  List<Transaction> transactions,
  DateTime now,
) {
  double spent = 0;
  double income = 0;
  var hasActivity = false;

  for (final transaction in transactions) {
    if (!_isSameDay(transaction.createdAt, now)) {
      continue;
    }
    hasActivity = true;
    final type = transaction.transactionType.toLowerCase();
    if (type == 'income') {
      income += transaction.amount;
    } else if (type == 'expense') {
      spent += transaction.amount;
    }
  }

  return TodaysMoneySummary(spent: spent, income: income, hasActivity: hasActivity);
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

enum UpcomingAttentionType { overdueBill, dueSoonBill, recurringPayment, loanEmi }

@immutable
class UpcomingAttentionItem {
  const UpcomingAttentionItem({
    required this.type,
    required this.title,
    required this.amount,
    required this.dueDate,
  });

  final UpcomingAttentionType type;
  final String title;
  final double amount;
  final DateTime dueDate;
}

/// Picks the single most urgent thing the user should look at, in priority
/// order: overdue bill > bill due soon > upcoming recurring payment >
/// upcoming EMI. Returns null when nothing needs attention.
///
/// Deliberately takes the already-derived lists from [upcomingBillsProvider]
/// (overdue-first, then soonest-due, within 7 days), [upcomingPaymentsProvider]
/// (soonest first) and [loanSummaryProvider] instead of raw model lists, so
/// this doesn't re-derive filtering/sorting that already exists elsewhere.
UpcomingAttentionItem? selectUpcomingAttention({
  required List<Bill> upcomingBills,
  required List<RecurringTransaction> upcomingPayments,
  required LoanSummary loanSummary,
  required DateTime now,
}) {
  if (upcomingBills.isNotEmpty) {
    final bill = upcomingBills.first;
    return UpcomingAttentionItem(
      type: bill.isOverdue(now)
          ? UpcomingAttentionType.overdueBill
          : UpcomingAttentionType.dueSoonBill,
      title: bill.title,
      amount: bill.amount,
      dueDate: bill.dueDate,
    );
  }

  if (upcomingPayments.isNotEmpty) {
    final item = upcomingPayments.first;
    return UpcomingAttentionItem(
      type: UpcomingAttentionType.recurringPayment,
      title: item.title,
      amount: item.amount,
      dueDate: item.nextDueDate,
    );
  }

  if (loanSummary.nextEmiDate != null) {
    return UpcomingAttentionItem(
      type: UpcomingAttentionType.loanEmi,
      title: loanSummary.nextEmiLoanName,
      amount: loanSummary.nextEmiAmount,
      dueDate: loanSummary.nextEmiDate!,
    );
  }

  return null;
}

/// Picks the single most relevant goal to show: the incomplete goal with the
/// closest target date, or — if every goal is already complete — the one
/// with the highest progress. Null when there are no goals at all.
Goal? selectRelevantGoal(List<Goal> goals) {
  if (goals.isEmpty) {
    return null;
  }

  final incomplete = goals.where((g) => !g.isCompleted).toList()
    ..sort((a, b) => a.targetDate.compareTo(b.targetDate));
  if (incomplete.isNotEmpty) {
    return incomplete.first;
  }

  final sortedByProgress = goals.toList()
    ..sort((a, b) => b.progressPercentage.compareTo(a.progressPercentage));
  return sortedByProgress.first;
}
