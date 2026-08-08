import 'package:flutter/material.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/shared/widgets/app_card.dart';

class BillSummaryCard extends StatelessWidget {
  const BillSummaryCard({
    super.key,
    required this.totalBills,
    required this.unpaidBills,
    required this.overdueBills,
    required this.totalUnpaidAmount,
  });

  final int totalBills;
  final int unpaidBills;
  final int overdueBills;
  final double totalUnpaidAmount;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bills summary',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _SummaryRow(label: 'Total bills', value: '$totalBills'),
          const SizedBox(height: 12),
          _SummaryRow(label: 'Unpaid', value: '$unpaidBills'),
          const SizedBox(height: 12),
          _SummaryRow(
            label: 'Overdue',
            value: '$overdueBills',
            valueColor: overdueBills > 0 ? AppColors.danger : null,
          ),
          const SizedBox(height: 12),
          _SummaryRow(
            label: 'Total unpaid amount',
            value: '₹${totalUnpaidAmount.toStringAsFixed(0)}',
          ),
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
