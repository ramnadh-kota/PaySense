import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/transaction.dart';
import '../models/wallet.dart';
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

/// Real, non-archived wallets for the Account filter. `TransactionFilters
/// .account` stores a wallet's real id (matching how `Transaction.accountId`
/// is stored — see `wallet_account_resolver.dart`), never its display name,
/// so filtering by account actually matches transactions correctly.
final availableTransactionAccountsProvider = Provider<List<Wallet>>((ref) {
  final wallets = ref.watch(walletsProvider).value ?? const <Wallet>[];
  final active = wallets.where((w) => !w.isArchived).toList()
    ..sort((a, b) => a.name.compareTo(b.name));
  return active;
});
