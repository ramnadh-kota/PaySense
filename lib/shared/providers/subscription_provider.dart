import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/recurring_transaction.dart';
import '../models/subscription_summary.dart';
import '../utils/subscription_calculator.dart';
import 'recurring_transaction_provider.dart';

/// Lightweight sort options for the Subscriptions screen. 'all' leaves the
/// natural (eligibility) order in place.
enum SubscriptionSortOption { all, highestCost, lowestCost, upcoming }

/// Currently selected sort — local UI state, mirroring the
/// `selectedCashFlowMonthProvider`/`monthlyReviewSelectedMonthProvider`
/// pattern already used elsewhere in this app.
final subscriptionSortOptionProvider =
    StateProvider<SubscriptionSortOption>((ref) => SubscriptionSortOption.all);

/// Currently selected category filter. Null means "All categories".
final subscriptionCategoryFilterProvider = StateProvider<String?>((ref) => null);

/// Every eligible subscription/recurring service, derived from
/// [recurringTransactionsProvider] — no persistence, no second
/// recurring-payment system.
final eligibleSubscriptionsProvider = Provider<List<SubscriptionSummary>>((ref) {
  final items =
      ref.watch(recurringTransactionsProvider).value ?? const <RecurringTransaction>[];
  return SubscriptionCalculator.eligibleSubscriptions(
    recurringTransactions: items,
    now: DateTime.now(),
  );
});

/// [eligibleSubscriptionsProvider], filtered by
/// [subscriptionCategoryFilterProvider] and sorted by
/// [subscriptionSortOptionProvider] — powers the "All subscriptions" list.
final filteredSubscriptionsProvider = Provider<List<SubscriptionSummary>>((ref) {
  final subscriptions = ref.watch(eligibleSubscriptionsProvider);
  final sortOption = ref.watch(subscriptionSortOptionProvider);
  final category = ref.watch(subscriptionCategoryFilterProvider);

  final filtered = category == null
      ? subscriptions
      : subscriptions
          .where((s) => (s.category.isEmpty ? 'Uncategorized' : s.category) == category)
          .toList();

  switch (sortOption) {
    case SubscriptionSortOption.highestCost:
      return SubscriptionCalculator.sortByCostDescending(filtered);
    case SubscriptionSortOption.lowestCost:
      return SubscriptionCalculator.sortByCostAscending(filtered);
    case SubscriptionSortOption.upcoming:
      return SubscriptionCalculator.sortByUpcoming(filtered);
    case SubscriptionSortOption.all:
      return filtered;
  }
});

/// The next 5 upcoming/overdue renewals, independent of the list filter —
/// powers the "Upcoming" section and the compact Dashboard card.
final subscriptionUpcomingRenewalsProvider = Provider<List<SubscriptionSummary>>((ref) {
  final subscriptions = ref.watch(eligibleSubscriptionsProvider);
  return SubscriptionCalculator.upcomingRenewals(subscriptions);
});

/// Monthly/annual totals, active count, and category breakdown across every
/// eligible subscription.
final subscriptionTotalsProvider = Provider<SubscriptionTotals>((ref) {
  final subscriptions = ref.watch(eligibleSubscriptionsProvider);
  return SubscriptionCalculator.summarize(subscriptions);
});
