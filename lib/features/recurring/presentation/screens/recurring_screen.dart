import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/features/recurring/presentation/widgets/recurring_summary_card.dart';
import 'package:paysense/features/recurring/presentation/widgets/recurring_transaction_card.dart';
import 'package:paysense/features/recurring/presentation/widgets/recurring_transaction_form_sheet.dart';
import 'package:paysense/shared/models/recurring_transaction.dart';
import 'package:paysense/shared/models/wallet.dart';
import 'package:paysense/shared/providers/recurring_transaction_provider.dart';
import 'package:paysense/shared/providers/wallet_provider.dart';
import 'package:paysense/shared/widgets/app_card.dart';

class RecurringScreen extends ConsumerWidget {
  const RecurringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(recurringTransactionsProvider);
    final totals = ref.watch(recurringTotalsProvider);
    final upcoming = ref.watch(upcomingPaymentsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('Recurring'),
        titleTextStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      body: SafeArea(
        child: itemsAsync.when(
          data: (items) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RecurringSummaryCard(
                    totalActive: totals.totalActive,
                    monthlyRecurringIncome: totals.monthlyRecurringIncome,
                    monthlyRecurringExpense: totals.monthlyRecurringExpense,
                    upcomingCount: upcoming.length,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Recurring',
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: () => _showForm(context, ref),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text('New recurring'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (items.isEmpty)
                    AppCard(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No recurring transactions yet. Add a subscription, EMI, '
                        'or salary to automate it.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    )
                  else
                    Column(
                      children: items
                          .map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: RecurringTransactionCard(
                                item: item,
                                onEdit: () => _showForm(context, ref, item: item),
                                onDelete: () => _delete(context, ref, item.id),
                                onToggleActive: (value) => ref
                                    .read(recurringTransactionsProvider.notifier)
                                    .setActive(item.id, value),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Unable to load recurring transactions right now.',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showForm(
    BuildContext context,
    WidgetRef ref, {
    RecurringTransaction? item,
  }) async {
    final allWallets = ref.read(walletsProvider).value ?? const <Wallet>[];
    final wallets = allWallets.where((w) => !w.isArchived || w.id == item?.accountId).toList();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return RecurringTransactionFormSheet(
          item: item,
          wallets: wallets,
          onSave: (updated) async {
            if (item == null) {
              await ref
                  .read(recurringTransactionsProvider.notifier)
                  .addRecurringTransaction(updated);
            } else {
              await ref
                  .read(recurringTransactionsProvider.notifier)
                  .updateRecurringTransaction(updated);
            }
            if (context.mounted) {
              Navigator.of(context).pop();
            }
          },
        );
      },
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete recurring transaction'),
        content: const Text(
          'Are you sure you want to remove this recurring transaction? '
          'Past generated transactions will not be affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(recurringTransactionsProvider.notifier).deleteRecurringTransaction(id);
    }
  }
}
