import 'package:flutter/material.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/shared/widgets/app_card.dart';

class BudgetSummaryCard extends StatelessWidget {
  const BudgetSummaryCard({
    super.key,
    required this.totalBudget,
    required this.totalSpent,
    required this.remainingBudget,
    required this.percentageUsed,
  });

  final double totalBudget;
  final double totalSpent;
  final double remainingBudget;
  final double percentageUsed;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Budget summary',
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
                    _SummaryRow(
                      label: 'Total budget',
                      value: '₹${totalBudget.toStringAsFixed(0)}',
                    ),
                    const SizedBox(height: 12),
                    _SummaryRow(
                      label: 'Spent',
                      value: '₹${totalSpent.toStringAsFixed(0)}',
                    ),
                    const SizedBox(height: 12),
                    _SummaryRow(
                      label: 'Remaining',
                      value: '₹${remainingBudget.toStringAsFixed(0)}',
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              _ProgressCircle(percentage: percentageUsed),
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
                'used',
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
