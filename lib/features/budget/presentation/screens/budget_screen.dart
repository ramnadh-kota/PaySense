import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/shared/models/budget.dart';
import 'package:paysense/shared/providers/budget_provider.dart';
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
                  if (budgets.isEmpty)
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
                      children: budgets
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
