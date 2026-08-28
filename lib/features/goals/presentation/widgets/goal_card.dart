import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/features/goals/presentation/goal_presets.dart';
import 'package:paysense/shared/models/goal.dart';
import 'package:paysense/shared/utils/financial_planning_calculator.dart'
    show GoalProjection, GoalProjectionStatus, GoalProjectionWeekly;
import 'package:paysense/shared/widgets/app_card.dart';

/// GOAL INTELLIGENCE — [projection] reuses `FinancialPlanningCalculator`'s
/// EXISTING [GoalProjection] output (see `GoalsScreen`) rather than a
/// second projection engine. Null when the goal is too new for any
/// projection to be computed yet (see [GoalProjection.impliedMonthlyContribution]'s
/// doc) — every intelligence row below is simply omitted in that case,
/// never a fabricated estimate.
class GoalCard extends StatelessWidget {
  const GoalCard({
    super.key,
    required this.goal,
    required this.onEdit,
    required this.onDelete,
    this.projection,
  });

  final Goal goal;
  final GoalProjection? projection;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final color = Color(goal.color);

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(iconForKey(goal.icon), color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            goal.title,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                          ),
                        ),
                        if (goal.isCompleted)
                          Icon(
                            Icons.celebration_rounded,
                            color: AppColors.success,
                            size: 20,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${goal.category} · Due ${goal.targetDate.day}/${goal.targetDate.month}/${goal.targetDate.year}',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onEdit,
                icon: Icon(Icons.edit_outlined, color: AppColors.primary),
              ),
              IconButton(
                onPressed: onDelete,
                icon: Icon(Icons.delete_outline, color: AppColors.danger),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: (goal.progressPercentage / 100).clamp(0.0, 1.0),
            color: color,
            backgroundColor: AppColors.surface,
            minHeight: 10,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Saved: ₹${goal.currentAmount.toStringAsFixed(0)}',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary),
              ),
              Text(
                '${goal.progressPercentage.toStringAsFixed(0)}%',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Target: ₹${goal.targetAmount.toStringAsFixed(0)} · Remaining: ₹${goal.remainingAmount.toStringAsFixed(0)}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          if (projection != null && !goal.isCompleted) _GoalIntelligence(projection: projection!),
        ],
      ),
    );
  }
}

class _GoalIntelligence extends StatelessWidget {
  const _GoalIntelligence({required this.projection});
  final GoalProjection projection;

  (Color, IconData, String) _statusVisuals() {
    switch (projection.status) {
      case GoalProjectionStatus.onTrack:
        return (AppColors.success, Icons.trending_up_rounded, 'On track');
      case GoalProjectionStatus.atRisk:
        return (AppColors.warning, Icons.trending_down_rounded, 'Recent pace may delay this goal');
      case GoalProjectionStatus.completed:
        return (AppColors.success, Icons.celebration_rounded, 'Completed');
      case GoalProjectionStatus.insufficientData:
        return (AppColors.textSecondary, Icons.hourglass_empty_rounded, 'Not enough history yet');
    }
  }

  @override
  Widget build(BuildContext context) {
    final requiredMonthly = projection.requiredMonthlyContribution;
    final requiredWeekly = projection.requiredWeeklyContribution;
    final completion = projection.estimatedCompletionDate;
    if (requiredMonthly == null && completion == null && projection.status == GoalProjectionStatus.insufficientData) {
      return const SizedBox.shrink();
    }

    final (color, icon, statusLabel) = _statusVisuals();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 15, color: color),
                const SizedBox(width: 6),
                Text(
                  statusLabel,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700, color: color),
                ),
              ],
            ),
            if (requiredWeekly != null && requiredMonthly != null) ...[
              const SizedBox(height: 6),
              Text(
                'Save about ₹${requiredWeekly.toStringAsFixed(0)}/week (₹${requiredMonthly.toStringAsFixed(0)}/month) to stay on track.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textPrimary),
              ),
            ],
            if (completion != null) ...[
              const SizedBox(height: 4),
              Text(
                'At your current pace, about ${DateFormat('MMM yyyy').format(completion)}.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
