import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/features/goals/presentation/widgets/goal_card.dart';
import 'package:paysense/features/goals/presentation/widgets/goal_form_sheet.dart';
import 'package:paysense/features/goals/presentation/widgets/goal_summary_card.dart';
import 'package:paysense/shared/models/goal.dart';
import 'package:paysense/shared/providers/goal_provider.dart';
import 'package:paysense/shared/widgets/app_card.dart';

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(goalsProvider);
    final totals = ref.watch(goalTotalsProvider);
    final percentageSaved = totals.totalTarget > 0
        ? (totals.totalSaved / totals.totalTarget * 100).clamp(0.0, 100.0)
        : 0.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('Goals'),
        titleTextStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      body: SafeArea(
        child: goalsAsync.when(
          data: (goals) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GoalSummaryCard(
                    totalGoals: totals.totalGoals,
                    totalTarget: totals.totalTarget,
                    totalSaved: totals.totalSaved,
                    totalRemaining: totals.totalRemaining,
                    percentageSaved: percentageSaved,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Your goals',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      FilledButton(
                        onPressed: () => _showGoalForm(context, ref),
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
                        child: const Text('New goal'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (goals.isEmpty)
                    AppCard(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No goals yet. Create a savings goal to start tracking progress.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    )
                  else
                    Column(
                      children: goals
                          .map(
                            (goal) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: GoalCard(
                                goal: goal,
                                onEdit: () =>
                                    _showGoalForm(context, ref, goal: goal),
                                onDelete: () =>
                                    _deleteGoal(context, ref, goal.id),
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
                'Unable to load goals right now.',
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

  Future<void> _showGoalForm(
    BuildContext context,
    WidgetRef ref, {
    Goal? goal,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return GoalFormSheet(
          goal: goal,
          onSave: (updatedGoal) async {
            if (goal == null) {
              await ref.read(goalsProvider.notifier).addGoal(updatedGoal);
            } else {
              await ref.read(goalsProvider.notifier).updateGoal(updatedGoal);
            }
            if (context.mounted) {
              Navigator.of(context).pop();
            }
          },
        );
      },
    );
  }

  Future<void> _deleteGoal(BuildContext context, WidgetRef ref, String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete goal'),
        content: const Text('Are you sure you want to remove this goal?'),
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
      await ref.read(goalsProvider.notifier).deleteGoal(id);
    }
  }
}
