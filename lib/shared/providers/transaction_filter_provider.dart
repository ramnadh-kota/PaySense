import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/transaction.dart';
import '../utils/transaction_filters.dart';
import 'transaction_provider.dart';
import 'wallet_provider.dart';

final transactionFilterProvider =
    NotifierProvider<TransactionFilterNotifier, TransactionFilterState>(
      TransactionFilterNotifier.new,
    );

class TransactionFilterNotifier extends Notifier<TransactionFilterState> {
  @override
  TransactionFilterState build() => const TransactionFilterState();

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setType(TransactionTypeFilter type) {
    state = state.copyWith(type: type);
  }

  void setCategory(String? category) {
    state = category == null
        ? state.copyWith(clearCategory: true)
        : state.copyWith(category: category);
  }

  void setAccount(String? account) {
    state = account == null
        ? state.copyWith(clearAccount: true)
        : state.copyWith(account: account);
  }

  void setDateRange(DateRangeFilter range) {
    state = state.copyWith(dateRange: range);
  }

  void setCustomDateRange(DateTime start, DateTime end) {
    state = state.copyWith(
      dateRange: DateRangeFilter.custom,
      customStart: start,
      customEnd: end,
    );
  }

  void setAmountRange({double? min, double? max}) {
    state = state.withAmountRange(min: min, max: max);
  }

  void setSort(TransactionSortOption sort) {
    state = state.copyWith(sort: sort);
  }

  void clearAll() {
    state = const TransactionFilterState();
  }
}

/// The current transaction list with search/filters/sort applied. Purely
/// derived from [transactionsProvider] — no second data store.
final filteredTransactionsProvider = Provider<List<Transaction>>((ref) {
  final transactions =
      ref.watch(transactionsProvider).value ?? const <Transaction>[];
  final filters = ref.watch(transactionFilterProvider);
  return TransactionFilterEngine.apply(transactions, filters);
});

/// Distinct categories actually present in the stored transactions, so the
/// filter sheet never hardcodes a category list.
final availableTransactionCategoriesProvider = Provider<List<String>>((ref) {
  final transactions =
      ref.watch(transactionsProvider).value ?? const <Transaction>[];
  final categories =
      transactions
          .map((t) => t.categoryId)
          .where((c) => c.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
  return categories;
});

/// Wallet names, sourced from the existing wallets list rather than
/// hardcoded, for the Account filter.
final availableTransactionAccountsProvider = Provider<List<String>>((ref) {
  final wallets = ref.watch(walletsProvider).value ?? const [];
  final names = wallets.map((w) => w.name).where((n) => n.isNotEmpty).toSet().toList()
    ..sort();
  return names;
});
