import 'package:flutter/material.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/shared/models/loan.dart';
import 'package:paysense/shared/widgets/app_card.dart';

class LoanCard extends StatelessWidget {
  const LoanCard({
    super.key,
    required this.loan,
    required this.onEdit,
    required this.onDelete,
    required this.onPayEmi,
    required this.onClose,
  });

  final Loan loan;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onPayEmi;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isOverdue = loan.isOverdue(now);
    final statusColor = loan.isClosed
        ? AppColors.textSecondary
        : (isOverdue ? AppColors.danger : AppColors.success);
    final progress = loan.principalAmount > 0
        ? (loan.paidAmount / loan.principalAmount).clamp(0.0, 1.0)
        : 0.0;

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
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.account_balance_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loan.loanName,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${loan.lenderName} · ${loan.loanType}',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  loan.isClosed ? 'Closed' : (isOverdue ? 'Overdue' : 'Active'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: progress,
            color: AppColors.primary,
            backgroundColor: AppColors.surface,
            minHeight: 10,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Outstanding: ₹${loan.outstandingAmount.toStringAsFixed(0)}',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary),
              ),
              Text(
                '${(progress * 100).toStringAsFixed(0)}% paid',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            loan.isClosed
                ? 'EMI: ₹${loan.emiAmount.toStringAsFixed(0)}'
                : 'EMI: ₹${loan.emiAmount.toStringAsFixed(0)} · Next due ${_formatDate(loan.nextDueDate)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: isOverdue ? AppColors.danger : AppColors.textSecondary,
              fontWeight: isOverdue ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (loan.isActive) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: onPayEmi,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Pay EMI'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onClose,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.divider),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Close'),
                  ),
                ),
              ] else
                const Expanded(child: SizedBox.shrink()),
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, color: AppColors.danger),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) =>
      '${date.day}/${date.month}/${date.year}';
}
