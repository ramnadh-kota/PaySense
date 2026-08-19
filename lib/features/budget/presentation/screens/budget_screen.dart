import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/shared/models/budget.dart';
import 'package:paysense/shared/providers/budget_provider.dart';
import 'package:paysense/shared/utils/budget_calculator.dart';
import 'package:paysense/shared/widgets/app_card.dart';
import 'package:paysense/features/budget/presentation/widgets/budget_category_card.dart';
import 'package:paysense/features/budget/presentation/widgets/budget_summary_card.dart';
import 'package:paysense/features/budget/presentation/widgets/budget_form_sheet.dart';

class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetsAsync = ref.watch(budgetsProvider);
    final totals = ref.watch(budgetTotalsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('Budgets'),
        titleTextStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      body: SafeArea(
        child: budgetsAsync.when(
          data: (budgets) {
            final overspend = BudgetCalculator.overspendSummary(budgets);
            final nearLimit = BudgetCalculator.nearLimitCount(budgets);
            final sortedBudgets = BudgetCalculator.sortByPerformance(budgets);
            final history = BudgetCalculator.history(budgets);

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BudgetSummaryCard(
                    totalBudget: totals.totalBudget,
                    totalSpent: totals.totalSpent,
                    remainingBudget: totals.remainingBudget,
                    percentageUsed: totals.percentageUsed,
                  ),
                  if (overspend.hasOverspend) ...[
                    const SizedBox(height: 16),
                    _OverBudgetBanner(overspend: overspend),
                  ],
                  if (nearLimit > 0) ...[
                    const SizedBox(height: 16),
                    _NearLimitBanner(count: nearLimit),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Category budgets',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      FilledButton(
                        onPressed: () => _showBudgetForm(context, ref),
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
                        child: const Text('New budget'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (sortedBudgets.isEmpty)
                    AppCard(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No budgets yet. Create a category budget to track spending automatically.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    )
                  else
                    Column(
                      children: sortedBudgets
                          .map(
                            (budget) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: BudgetCategoryCard(
                                budget: budget,
                                onEdit: () => _showBudgetForm(
                                  context,
                                  ref,
                                  budget: budget,
                                ),
                                onDelete: () =>
                                    _deleteBudget(context, ref, budget.id),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  if (history.length > 1) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Budget history',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _MonthOverMonthCard(
                      comparison: BudgetCalculator.compareMonths(
                        currentMonthBudgets: budgets
                            .where(
                              (b) =>
                                  b.month == history.first.month &&
                                  b.year == history.first.year,
                            )
                            .toList(),
                        previousMonthBudgets: budgets
                            .where(
                              (b) =>
                                  b.month == history[1].month &&
                                  b.year == history[1].year,
                            )
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Column(
                      children: history
                          .map(
                            (group) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _BudgetHistoryTile(group: group),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Unable to load budgets right now.',
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

  Future<void> _showBudgetForm(
    BuildContext context,
    WidgetRef ref, {
    Budget? budget,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return BudgetFormSheet(
          budget: budget,
          onSave: (updatedBudget) async {
            if (budget == null) {
              await ref.read(budgetsProvider.notifier).addBudget(updatedBudget);
            } else {
              await ref
                  .read(budgetsProvider.notifier)
                  .updateBudget(updatedBudget);
            }
            if (context.mounted) {
              Navigator.of(context).pop();
            }
          },
        );
      },
    );
  }

  Future<void> _deleteBudget(
    BuildContext context,
    WidgetRef ref,
    String id,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete budget'),
        content: const Text('Are you sure you want to remove this budget?'),
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
      await ref.read(budgetsProvider.notifier).deleteBudget(id);
    }
  }
}

class _OverBudgetBanner extends StatelessWidget {
  const _OverBudgetBanner({required this.overspend});

  final BudgetOverspendSummary overspend;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      color: AppColors.danger.withValues(alpha: 0.08),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: AppColors.danger),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'You are ₹${overspend.totalOverspend.toStringAsFixed(0)} over '
              'budget across ${overspend.categoryCount} '
              '${overspend.categoryCount == 1 ? 'category' : 'categories'}.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NearLimitBanner extends StatelessWidget {
  const _NearLimitBanner({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      color: AppColors.warning.withValues(alpha: 0.1),
      child: Row(
        children: [
          Icon(Icons.timelapse_rounded, color: AppColors.warning),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$count ${count == 1 ? 'category is' : 'categories are'} '
              'approaching ${count == 1 ? 'its' : 'their'} limits.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.warning,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthOverMonthCard extends StatelessWidget {
  const _MonthOverMonthCard({required this.comparison});

  final BudgetPeriodComparison comparison;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Vs previous month',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _ChangeRow(label: 'Budgeted', change: comparison.budgetChange),
          const SizedBox(height: 8),
          _ChangeRow(label: 'Spent', change: comparison.spentChange),
        ],
      ),
    );
  }
}

class _ChangeRow extends StatelessWidget {
  const _ChangeRow({required this.label, required this.change});

  final String label;
  final BudgetChangeValue change;

  @override
  Widget build(BuildContext context) {
    final String changeText;
    final Color changeColor;
    if (change.isNew) {
      changeText = 'New this month';
      changeColor = AppColors.textSecondary;
    } else if (change.percentage == null) {
      changeText = 'No change';
      changeColor = AppColors.textSecondary;
    } else {
      final pct = change.percentage!;
      final sign = pct > 0 ? '+' : '';
      changeText = '$sign${pct.toStringAsFixed(0)}%';
      changeColor = pct > 0 ? AppColors.danger : AppColors.success;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
        Text(
          '₹${change.current.toStringAsFixed(0)}  ($changeText)',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: changeColor,
          ),
        ),
      ],
    );
  }
}

class _BudgetHistoryTile extends StatelessWidget {
  const _BudgetHistoryTile({required this.group});

  final BudgetMonthGroup group;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (group.status) {
      BudgetStatus.overBudget => AppColors.danger,
      BudgetStatus.nearLimit => AppColors.warning,
      BudgetStatus.underBudget => AppColors.success,
    };

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${group.month} ${group.year}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              _StatusChip(status: group.status, color: statusColor),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _HistoryStat(label: 'Budgeted', value: group.summary.totalBudget),
              _HistoryStat(label: 'Spent', value: group.summary.totalSpent),
              _HistoryStat(
                label: group.summary.totalRemaining < 0 ? 'Over' : 'Remaining',
                value: group.summary.totalRemaining.abs(),
                valueColor: group.summary.totalRemaining < 0
                    ? AppColors.danger
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HistoryStat extends StatelessWidget {
  const _HistoryStat({required this.label, required this.value, this.valueColor});

  final String label;
  final double value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
            fontSize: 11,
          ),
        ),
        Text(
          '₹${value.toStringAsFixed(0)}',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.color});

  final BudgetStatus status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11),
      ),
    );
  }
}
