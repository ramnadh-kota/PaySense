import 'package:flutter/material.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/shared/widgets/app_card.dart';

class GoalSummaryCard extends StatelessWidget {
  const GoalSummaryCard({
    super.key,
    required this.totalGoals,
    required this.totalTarget,
    required this.totalSaved,
    required this.totalRemaining,
    required this.percentageSaved,
  });

  final int totalGoals;
  final double totalTarget;
  final double totalSaved;
  final double totalRemaining;
  final double percentageSaved;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Goals summary',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SummaryRow(label: 'Total goals', value: '$totalGoals'),
                    const SizedBox(height: 12),
                    _SummaryRow(
                      label: 'Target',
                      value: '₹${totalTarget.toStringAsFixed(0)}',
                    ),
                    const SizedBox(height: 12),
                    _SummaryRow(
                      label: 'Saved',
                      value: '₹${totalSaved.toStringAsFixed(0)}',
                    ),
                    const SizedBox(height: 12),
                    _SummaryRow(
                      label: 'Remaining',
                      value: '₹${totalRemaining.toStringAsFixed(0)}',
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              _ProgressCircle(percentage: percentageSaved),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProgressCircle extends StatelessWidget {
  const _ProgressCircle({required this.percentage});

  final double percentage;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 88,
      height: 88,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: (percentage / 100).clamp(0.0, 1.0),
            strokeWidth: 10,
            color: AppColors.primary,
            backgroundColor: AppColors.surface,
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${percentage.toStringAsFixed(0)}%',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                'saved',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
