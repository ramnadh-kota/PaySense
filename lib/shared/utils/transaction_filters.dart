import 'package:flutter/foundation.dart';

import '../models/transaction.dart';

enum TransactionTypeFilter { all, income, expense }

enum DateRangeFilter { all, today, thisWeek, thisMonth, lastMonth, custom }

enum TransactionSortOption { newestFirst, oldestFirst, highestAmount, lowestAmount }

/// Search + filter + sort criteria for the Transactions screen. Purely a
/// view-level query — never persisted, never mutates stored transactions.
@immutable
class TransactionFilterState {
  const TransactionFilterState({
    this.searchQuery = '',
    this.type = TransactionTypeFilter.all,
    this.category,
    this.dateRange = DateRangeFilter.all,
    this.customStart,
    this.customEnd,
    this.account,
    this.minAmount,
    this.maxAmount,
    this.sort = TransactionSortOption.newestFirst,
  });

  final String searchQuery;
  final TransactionTypeFilter type;
  final String? category;
  final DateRangeFilter dateRange;
  final DateTime? customStart;
  final DateTime? customEnd;
  final String? account;
  final double? minAmount;
  final double? maxAmount;
  final TransactionSortOption sort;

  /// Whether any filter (excluding search text and sort order) is active.
  bool get hasActiveFilters =>
      type != TransactionTypeFilter.all ||
      category != null ||
      dateRange != DateRangeFilter.all ||
      account != null ||
      minAmount != null ||
      maxAmount != null;

  int get activeFilterCount {
    var count = 0;
    if (type != TransactionTypeFilter.all) count++;
    if (category != null) count++;
    if (dateRange != DateRangeFilter.all) count++;
    if (account != null) count++;
    if (minAmount != null || maxAmount != null) count++;
    return count;
  }

  TransactionFilterState copyWith({
    String? searchQuery,
    TransactionTypeFilter? type,
    String? category,
    bool clearCategory = false,
    DateRangeFilter? dateRange,
    DateTime? customStart,
    DateTime? customEnd,
    String? account,
    bool clearAccount = false,
    TransactionSortOption? sort,
  }) {
    return TransactionFilterState(
      searchQuery: searchQuery ?? this.searchQuery,
      type: type ?? this.type,
      category: clearCategory ? null : (category ?? this.category),
      dateRange: dateRange ?? this.dateRange,
      customStart: customStart ?? this.customStart,
      customEnd: customEnd ?? this.customEnd,
      account: clearAccount ? null : (account ?? this.account),
      minAmount: minAmount,
      maxAmount: maxAmount,
      sort: sort ?? this.sort,
    );
  }

  /// Amount bounds are replaced wholesale (not merged via `??`) since either
  /// bound must be independently clearable to null.
  TransactionFilterState withAmountRange({double? min, double? max}) {
    return TransactionFilterState(
      searchQuery: searchQuery,
      type: type,
      category: category,
      dateRange: dateRange,
      customStart: customStart,
      customEnd: customEnd,
      account: account,
      minAmount: min,
      maxAmount: max,
      sort: sort,
    );
  }
}

/// Pure filtering/sorting for the Transactions screen. No Flutter or
/// Riverpod dependency, so it's directly unit-testable.
class TransactionFilterEngine {
  TransactionFilterEngine._();

  static List<Transaction> apply(
    List<Transaction> transactions,
    TransactionFilterState filters, {
    DateTime? now,
  }) {
    final referenceNow = now ?? DateTime.now();
    final query = filters.searchQuery.trim().toLowerCase();

    final filtered = transactions.where((transaction) {
      if (query.isNotEmpty && !_matchesSearch(transaction, query)) {
        return false;
      }
      if (!_matchesType(transaction, filters.type)) {
        return false;
      }
      if (filters.category != null &&
          transaction.categoryId != filters.category) {
        return false;
      }
      if (filters.account != null && transaction.accountId != filters.account) {
        return false;
      }
      if (!_matchesDateRange(transaction, filters, referenceNow)) {
        return false;
      }
      if (filters.minAmount != null && transaction.amount < filters.minAmount!) {
        return false;
      }
      if (filters.maxAmount != null && transaction.amount > filters.maxAmount!) {
        return false;
      }
      return true;
    }).toList();

    filtered.sort((a, b) => _compare(a, b, filters.sort));
    return filtered;
  }

  static bool _matchesSearch(Transaction transaction, String query) {
    return transaction.title.toLowerCase().contains(query) ||
        transaction.categoryId.toLowerCase().contains(query) ||
        transaction.note.toLowerCase().contains(query) ||
        transaction.accountId.toLowerCase().contains(query);
  }

  static bool _matchesType(Transaction transaction, TransactionTypeFilter type) {
    switch (type) {
      case TransactionTypeFilter.all:
        return true;
      case TransactionTypeFilter.income:
        return transaction.transactionType.toLowerCase() == 'income';
      case TransactionTypeFilter.expense:
        return transaction.transactionType.toLowerCase() == 'expense';
    }
  }

  static bool _matchesDateRange(
    Transaction transaction,
    TransactionFilterState filters,
    DateTime now,
  ) {
    switch (filters.dateRange) {
      case DateRangeFilter.all:
        return true;
      case DateRangeFilter.today:
        return _isSameDay(transaction.createdAt, now);
      case DateRangeFilter.thisWeek:
        final startOfWeek = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: now.weekday - 1));
        final endOfWeek = startOfWeek.add(const Duration(days: 7));
        return !transaction.createdAt.isBefore(startOfWeek) &&
            transaction.createdAt.isBefore(endOfWeek);
      case DateRangeFilter.thisMonth:
        return transaction.createdAt.year == now.year &&
            transaction.createdAt.month == now.month;
      case DateRangeFilter.lastMonth:
        final lastMonth = DateTime(now.year, now.month - 1, 1);
        return transaction.createdAt.year == lastMonth.year &&
            transaction.createdAt.month == lastMonth.month;
      case DateRangeFilter.custom:
        final start = filters.customStart;
        final end = filters.customEnd;
        if (start == null || end == null) {
          return true;
        }
        final startOfDay = DateTime(start.year, start.month, start.day);
        final endOfDay = DateTime(end.year, end.month, end.day, 23, 59, 59, 999);
        return !transaction.createdAt.isBefore(startOfDay) &&
            !transaction.createdAt.isAfter(endOfDay);
    }
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static int _compare(Transaction a, Transaction b, TransactionSortOption sort) {
    switch (sort) {
      case TransactionSortOption.newestFirst:
        return b.createdAt.compareTo(a.createdAt);
      case TransactionSortOption.oldestFirst:
        return a.createdAt.compareTo(b.createdAt);
      case TransactionSortOption.highestAmount:
        return b.amount.compareTo(a.amount);
      case TransactionSortOption.lowestAmount:
        return a.amount.compareTo(b.amount);
    }
  }
}
