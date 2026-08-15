import 'package:flutter/foundation.dart';

import '../models/recurring_transaction.dart';
import '../models/subscription_summary.dart';

/// How many times a given [RecurringTransaction.frequency] occurs per year.
/// The basis for every cost calculation below: annual cost is computed
/// first (amount × occurrences/year), and the monthly equivalent is always
/// derived from that annual figure (`annualCost / 12`) rather than from a
/// separate, potentially-inconsistent monthly approximation.
const Map<String, int> subscriptionOccurrencesPerYear = {
  'Daily': 365,
  'Weekly': 52,
  'Monthly': 12,
  'Yearly': 1,
};

@immutable
class SubscriptionTotals {
  const SubscriptionTotals({
    required this.totalMonthlyCost,
    required this.totalAnnualCost,
    required this.activeCount,
    required this.averageMonthlyCost,
    required this.mostExpensive,
    required this.categoryTotals,
  });

  final double totalMonthlyCost;
  final double totalAnnualCost;
  final int activeCount;
  final double averageMonthlyCost;

  /// The single highest monthly-cost subscription, or null when there are
  /// none.
  final SubscriptionSummary? mostExpensive;

  /// Monthly-equivalent cost per category. Key is the category as recorded,
  /// or 'Uncategorized' when [SubscriptionSummary.category] is empty.
  final Map<String, double> categoryTotals;

  bool get hasSubscriptions => activeCount > 0;
}

/// Pure, deterministic Subscription Manager calculation. No Flutter/Riverpod
/// dependency — derives everything from existing [RecurringTransaction]
/// data. Read-only: never generates transactions, never touches wallet
/// balances, never modifies a recurring definition's schedule.
class SubscriptionCalculator {
  SubscriptionCalculator._();

  /// This subscription's annualized cost from a per-occurrence [amount] and
  /// [frequency]. See [subscriptionOccurrencesPerYear] for the methodology.
  static double annualCostFor(double amount, String frequency) {
    final occurrences = subscriptionOccurrencesPerYear[frequency];
    if (occurrences == null) return 0;
    return amount * occurrences;
  }

  /// Recurring transactions eligible to appear as a subscription/recurring
  /// service:
  /// - active
  /// - expense type (income recurring items are excluded)
  /// - not expired
  /// - a valid (positive) amount
  /// - a recognized frequency (so a monthly/annual cost can be reliably
  ///   computed) — see [subscriptionOccurrencesPerYear]
  ///
  /// Every result traces back to exactly one [RecurringTransaction]; a
  /// defensive dedup by id guards against ever surfacing the same source
  /// record twice even if the input list somehow contained a duplicate.
  static List<SubscriptionSummary> eligibleSubscriptions({
    required List<RecurringTransaction> recurringTransactions,
    required DateTime now,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    final seenIds = <String>{};
    final result = <SubscriptionSummary>[];

    for (final item in recurringTransactions) {
      if (!item.isActive) continue;
      if (item.isExpired) continue;
      if (item.transactionType.toLowerCase() != 'expense') continue;
      if (item.amount <= 0) continue;
      if (!subscriptionOccurrencesPerYear.containsKey(item.frequency)) continue;
      if (!seenIds.add(item.id)) continue;

      final annualCost = annualCostFor(item.amount, item.frequency);
      final overdue = item.nextDueDate.isBefore(today);

      result.add(
        SubscriptionSummary(
          id: item.id,
          name: item.title,
          amount: item.amount,
          frequency: item.frequency,
          nextDueDate: item.nextDueDate,
          category: item.categoryId.trim(),
          account: item.accountId,
          monthlyEquivalent: annualCost / 12,
          annualCost: annualCost,
          status: overdue ? SubscriptionStatus.overdue : SubscriptionStatus.active,
          sourceId: item.id,
        ),
      );
    }
    return result;
  }

  static double totalMonthlyCost(List<SubscriptionSummary> subscriptions) =>
      subscriptions.fold(0, (sum, s) => sum + s.monthlyEquivalent);

  static double totalAnnualCost(List<SubscriptionSummary> subscriptions) =>
      subscriptions.fold(0, (sum, s) => sum + s.annualCost);

  static double averageMonthlyCost(List<SubscriptionSummary> subscriptions) {
    if (subscriptions.isEmpty) return 0;
    return totalMonthlyCost(subscriptions) / subscriptions.length;
  }

  static SubscriptionTotals summarize(List<SubscriptionSummary> subscriptions) {
    final mostExpensiveList = sortByCostDescending(subscriptions);
    return SubscriptionTotals(
      totalMonthlyCost: totalMonthlyCost(subscriptions),
      totalAnnualCost: totalAnnualCost(subscriptions),
      activeCount: subscriptions.length,
      averageMonthlyCost: averageMonthlyCost(subscriptions),
      mostExpensive: mostExpensiveList.isEmpty ? null : mostExpensiveList.first,
      categoryTotals: categoryTotals(subscriptions),
    );
  }

  /// The next [limit] renewals, soonest [SubscriptionSummary.nextDueDate]
  /// first (overdue items sort first, since their due date is in the past).
  static List<SubscriptionSummary> upcomingRenewals(
    List<SubscriptionSummary> subscriptions, {
    int limit = 5,
  }) {
    final sorted = sortByUpcoming(subscriptions);
    return sorted.take(limit).toList();
  }

  static List<SubscriptionSummary> sortByUpcoming(List<SubscriptionSummary> subscriptions) {
    return [...subscriptions]..sort((a, b) => a.nextDueDate.compareTo(b.nextDueDate));
  }

  static List<SubscriptionSummary> sortByCostDescending(List<SubscriptionSummary> subscriptions) {
    return [...subscriptions]..sort((a, b) => b.monthlyEquivalent.compareTo(a.monthlyEquivalent));
  }

  static List<SubscriptionSummary> sortByCostAscending(List<SubscriptionSummary> subscriptions) {
    return [...subscriptions]..sort((a, b) => a.monthlyEquivalent.compareTo(b.monthlyEquivalent));
  }

  /// The single most expensive subscription by monthly-equivalent cost, or
  /// null when there are none.
  static SubscriptionSummary? mostExpensive(List<SubscriptionSummary> subscriptions) {
    final sorted = sortByCostDescending(subscriptions);
    return sorted.isEmpty ? null : sorted.first;
  }

  /// Monthly-equivalent cost grouped by category. Never fabricates a
  /// category: an empty [SubscriptionSummary.category] is grouped under
  /// 'Uncategorized' rather than guessed.
  static Map<String, double> categoryTotals(List<SubscriptionSummary> subscriptions) {
    final totals = <String, double>{};
    for (final s in subscriptions) {
      final key = s.category.isEmpty ? 'Uncategorized' : s.category;
      totals[key] = (totals[key] ?? 0) + s.monthlyEquivalent;
    }
    return totals;
  }
}
