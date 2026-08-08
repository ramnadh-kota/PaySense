import 'package:flutter/material.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/shared/models/bill.dart';
import 'package:paysense/shared/widgets/app_card.dart';

class BillCard extends StatelessWidget {
  const BillCard({
    super.key,
    required this.bill,
    required this.onEdit,
    required this.onDelete,
    required this.onMarkPaid,
    required this.onMarkUnpaid,
  });

  final Bill bill;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onMarkPaid;
  final VoidCallback onMarkUnpaid;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isOverdue = bill.isOverdue(now);
    final statusColor = bill.isPaid
        ? AppColors.success
        : (isOverdue ? AppColors.danger : AppColors.warning);
    final statusLabel = bill.isPaid
        ? 'Paid'
        : (isOverdue ? 'Overdue' : 'Unpaid');

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
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  bill.isRecurring
                      ? Icons.autorenew_rounded
                      : Icons.receipt_long_rounded,
                  color: statusColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bill.title,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${bill.categoryId} · ${bill.accountId}${bill.isRecurring ? ' · ${bill.frequency}' : ''}',
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
                  statusLabel,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '₹${bill.amount.toStringAsFixed(0)}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                'Due ${_formatDate(bill.dueDate)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isOverdue ? AppColors.danger : AppColors.textSecondary,
                  fontWeight: isOverdue ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: bill.isPaid ? onMarkUnpaid : onMarkPaid,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: bill.isPaid
                        ? AppColors.textSecondary
                        : AppColors.primary,
                    side: BorderSide(
                      color: bill.isPaid
                          ? AppColors.divider
                          : AppColors.primary,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(bill.isPaid ? 'Mark unpaid' : 'Mark paid'),
                ),
              ),
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
