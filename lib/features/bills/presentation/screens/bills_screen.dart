import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/features/bills/presentation/widgets/bill_card.dart';
import 'package:paysense/features/bills/presentation/widgets/bill_form_sheet.dart';
import 'package:paysense/features/bills/presentation/widgets/bill_summary_card.dart';
import 'package:paysense/shared/models/bill.dart';
import 'package:paysense/shared/providers/bill_provider.dart';
import 'package:paysense/shared/widgets/app_card.dart';

class BillsScreen extends ConsumerWidget {
  const BillsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final billsAsync = ref.watch(billsProvider);
    final totals = ref.watch(billTotalsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('Bills'),
        titleTextStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      body: SafeArea(
        child: billsAsync.when(
          data: (bills) {
            final sorted = bills.toList()
              ..sort((a, b) {
                if (a.isPaid != b.isPaid) {
                  return a.isPaid ? 1 : -1;
                }
                return a.dueDate.compareTo(b.dueDate);
              });

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BillSummaryCard(
                    totalBills: totals.totalBills,
                    unpaidBills: totals.unpaidBills,
                    overdueBills: totals.overdueBills,
                    totalUnpaidAmount: totals.totalUnpaidAmount,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Your bills',
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
                        child: const Text('New bill'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (sorted.isEmpty)
                    AppCard(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No bills yet. Add a subscription or utility bill to '
                        'start tracking due dates.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    )
                  else
                    Column(
                      children: sorted
                          .map(
                            (bill) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: BillCard(
                                bill: bill,
                                onEdit: () => _showForm(context, ref, bill: bill),
                                onDelete: () => _delete(context, ref, bill.id),
                                onMarkPaid: () =>
                                    ref.read(billsProvider.notifier).markPaid(bill.id),
                                onMarkUnpaid: () => ref
                                    .read(billsProvider.notifier)
                                    .markUnpaid(bill.id),
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
                'Unable to load bills right now.',
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
    Bill? bill,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return BillFormSheet(
          bill: bill,
          onSave: (updated) async {
            if (bill == null) {
              await ref.read(billsProvider.notifier).addBill(updated);
            } else {
              await ref.read(billsProvider.notifier).updateBill(updated);
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
        title: const Text('Delete bill'),
        content: const Text(
          'Are you sure you want to remove this bill? Past payment records '
          'will not be affected.',
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
      await ref.read(billsProvider.notifier).deleteBill(id);
    }
  }
}
