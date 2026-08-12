import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/shared/models/transaction.dart';
import 'package:paysense/shared/providers/transaction_filter_provider.dart';
import 'package:paysense/shared/providers/transaction_provider.dart';
import 'package:paysense/shared/providers/user_profile_provider.dart';
import 'package:paysense/shared/utils/currency_formatter.dart';
import 'package:paysense/shared/utils/transaction_filters.dart';
import 'package:paysense/shared/widgets/app_card.dart';

import 'widgets/transaction_filter_sheet.dart';
import '../../dashboard/widgets/transaction_item.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openFilterSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const TransactionFilterSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(transactionsProvider);
    final filters = ref.watch(transactionFilterProvider);
    final filteredTransactions = ref.watch(filteredTransactionsProvider);
    final currencyCode = ref.watch(userProfileProvider).value?.currency ?? 'INR';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: const Text('Transactions'),
      ),
      body: SafeArea(
        child: transactionsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(
            child: Text(
              'Unable to load transactions right now.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ),
          data: (_) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (value) => ref
                              .read(transactionFilterProvider.notifier)
                              .setSearchQuery(value),
                          decoration: InputDecoration(
                            hintText: 'Search title, category, note, account',
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              color: AppColors.textSecondary,
                            ),
                            suffixIcon: _searchController.text.isEmpty
                                ? null
                                : IconButton(
                                    icon: const Icon(Icons.close_rounded),
                                    onPressed: () {
                                      _searchController.clear();
                                      ref
                                          .read(transactionFilterProvider.notifier)
                                          .setSearchQuery('');
                                      setState(() {});
                                    },
                                  ),
                            filled: true,
                            fillColor: AppColors.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 14,
                            ),
                          ),
                          onSubmitted: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _FilterButton(
                        active: filters.hasActiveFilters,
                        count: filters.activeFilterCount,
                        onTap: _openFilterSheet,
                      ),
                      const SizedBox(width: 4),
                      PopupMenuButton<TransactionSortOption>(
                        icon: const Icon(
                          Icons.sort_rounded,
                          color: AppColors.textPrimary,
                        ),
                        initialValue: filters.sort,
                        onSelected: (value) => ref
                            .read(transactionFilterProvider.notifier)
                            .setSort(value),
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: TransactionSortOption.newestFirst,
                            child: Text('Newest first'),
                          ),
                          PopupMenuItem(
                            value: TransactionSortOption.oldestFirst,
                            child: Text('Oldest first'),
                          ),
                          PopupMenuItem(
                            value: TransactionSortOption.highestAmount,
                            child: Text('Highest amount'),
                          ),
                          PopupMenuItem(
                            value: TransactionSortOption.lowestAmount,
                            child: Text('Lowest amount'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${filteredTransactions.length} transaction${filteredTransactions.length == 1 ? '' : 's'} found',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: filteredTransactions.isEmpty
                      ? _EmptyState(hasFilters: filters.hasActiveFilters || filters.searchQuery.isNotEmpty)
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                          itemCount: filteredTransactions.length,
                          itemBuilder: (context, index) {
                            final transaction = filteredTransactions[index];
                            return AppCard(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: TransactionItem(
                                  title: transaction.title,
                                  subtitle: _subtitleFor(transaction),
                                  amount: _formatAmount(
                                    transaction.amount,
                                    transaction.transactionType,
                                    currencyCode,
                                  ),
                                  icon: _iconForTransactionType(
                                    transaction.transactionType,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _subtitleFor(Transaction transaction) {
    final parts = <String>[
      transaction.categoryId,
      if (transaction.note.isNotEmpty) transaction.note,
    ];
    return parts.join(' · ');
  }

  String _formatAmount(double amount, String transactionType, String currencyCode) {
    final sign = transactionType.toLowerCase() == 'income' ? '+' : '-';
    return '$sign${CurrencyFormatter.symbolFor(currencyCode)}${amount.toStringAsFixed(0)}';
  }

  IconData _iconForTransactionType(String transactionType) {
    return transactionType.toLowerCase() == 'income'
        ? Icons.account_balance_rounded
        : Icons.shopping_bag_rounded;
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.active,
    required this.count,
    required this.onTap,
  });

  final bool active;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: active ? AppColors.accent : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(
              Icons.tune_rounded,
              color: active ? Colors.white : AppColors.textPrimary,
            ),
            if (active)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasFilters});

  final bool hasFilters;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 56,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              'No transactions found',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              hasFilters
                  ? 'Try changing your filters or search.'
                  : 'Your transactions will show up here.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
