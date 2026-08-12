import 'package:flutter/material.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/shared/models/loan.dart';

/// Read-only display of a computed [EmiCalculation]. Used inside the loan
/// form to preview EMI/interest/total-payable as the user edits the
/// principal, rate, and tenure fields, or to confirm a manually entered EMI.
class EmiCalculatorWidget extends StatelessWidget {
  const EmiCalculatorWidget({super.key, required this.calculation});

  final EmiCalculation calculation;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.calculate_rounded,
                color: AppColors.primary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'EMI calculator',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _Row(
            label: 'Monthly EMI',
            value: '₹${calculation.emiAmount.toStringAsFixed(0)}',
            emphasize: true,
          ),
          const SizedBox(height: 6),
          _Row(
            label: 'Total interest',
            value: '₹${calculation.totalInterest.toStringAsFixed(0)}',
          ),
          const SizedBox(height: 6),
          _Row(
            label: 'Total payable',
            value: '₹${calculation.totalPayable.toStringAsFixed(0)}',
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

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
          style:
              (emphasize
                      ? Theme.of(context).textTheme.titleMedium
                      : Theme.of(context).textTheme.bodyMedium)
                  ?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
        ),
      ],
    );
  }
}
