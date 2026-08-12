import 'package:flutter/material.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/shared/widgets/app_card.dart';

class LoanSummaryCard extends StatelessWidget {
  const LoanSummaryCard({
    super.key,
    required this.totalLoans,
    required this.activeLoans,
    required this.closedLoans,
    required this.outstandingBalance,
    required this.totalEmiPerMonth,
    required this.totalInterest,
  });

  final int totalLoans;
  final int activeLoans;
  final int closedLoans;
  final double outstandingBalance;
  final double totalEmiPerMonth;
  final double totalInterest;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Loans summary',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _SummaryRow(label: 'Total loans', value: '$totalLoans'),
          const SizedBox(height: 12),
          _SummaryRow(label: 'Active', value: '$activeLoans'),
          const SizedBox(height: 12),
          _SummaryRow(label: 'Closed', value: '$closedLoans'),
          const SizedBox(height: 12),
          _SummaryRow(
            label: 'Outstanding balance',
            value: '₹${outstandingBalance.toStringAsFixed(0)}',
            valueColor: AppColors.danger,
          ),
          const SizedBox(height: 12),
          _SummaryRow(
            label: 'Total EMI / month',
            value: '₹${totalEmiPerMonth.toStringAsFixed(0)}',
          ),
          const SizedBox(height: 12),
          _SummaryRow(
            label: 'Total interest',
            value: '₹${totalInterest.toStringAsFixed(0)}',
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
