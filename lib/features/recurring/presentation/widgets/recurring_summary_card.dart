import 'package:flutter/material.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/shared/widgets/app_card.dart';

class RecurringSummaryCard extends StatelessWidget {
  const RecurringSummaryCard({
    super.key,
    required this.totalActive,
    required this.monthlyRecurringIncome,
    required this.monthlyRecurringExpense,
    required this.upcomingCount,
  });

  final int totalActive;
  final double monthlyRecurringIncome;
  final double monthlyRecurringExpense;
  final int upcomingCount;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recurring summary',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _SummaryRow(label: 'Active recurring items', value: '$totalActive'),
          const SizedBox(height: 12),
          _SummaryRow(
            label: 'Monthly recurring income',
            value: '₹${monthlyRecurringIncome.toStringAsFixed(0)}',
            valueColor: AppColors.success,
          ),
          const SizedBox(height: 12),
          _SummaryRow(
            label: 'Monthly recurring expense',
            value: '₹${monthlyRecurringExpense.toStringAsFixed(0)}',
            valueColor: AppColors.danger,
          ),
          const SizedBox(height: 12),
          _SummaryRow(label: 'Due within 7 days', value: '$upcomingCount'),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

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
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
