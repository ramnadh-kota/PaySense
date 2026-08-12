import 'package:flutter/material.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/shared/models/loan.dart';

/// Confirms an EMI payment before it's recorded, showing the amount and
/// which wallet it will be deducted from. Returns `true` if confirmed.
class PaymentConfirmationDialog extends StatelessWidget {
  const PaymentConfirmationDialog({super.key, required this.loan});

  final Loan loan;

  static Future<bool> show(BuildContext context, Loan loan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => PaymentConfirmationDialog(loan: loan),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final isFinalPayment = loan.outstandingAmount <= loan.emiAmount;

    return AlertDialog(
      title: const Text('Confirm EMI payment'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pay this month\'s EMI for "${loan.loanName}"?',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          _Row(label: 'Amount', value: '₹${loan.emiAmount.toStringAsFixed(0)}'),
          const SizedBox(height: 8),
          _Row(label: 'From account', value: loan.accountId),
          const SizedBox(height: 8),
          _Row(
            label: 'Outstanding after',
            value:
                '₹${(loan.outstandingAmount - loan.emiAmount).clamp(0, loan.principalAmount).toStringAsFixed(0)}',
          ),
          if (isFinalPayment) ...[
            const SizedBox(height: 12),
            Text(
              'This is the final installment — the loan will be marked Closed.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.success,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
          child: const Text('Confirm payment'),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

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
