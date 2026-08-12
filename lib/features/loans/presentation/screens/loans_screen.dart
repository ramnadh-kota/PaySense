import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/features/loans/presentation/widgets/loan_card.dart';
import 'package:paysense/features/loans/presentation/widgets/loan_form_sheet.dart';
import 'package:paysense/features/loans/presentation/widgets/loan_summary_card.dart';
import 'package:paysense/features/loans/presentation/widgets/payment_confirmation_dialog.dart';
import 'package:paysense/shared/models/loan.dart';
import 'package:paysense/shared/providers/loan_provider.dart';
import 'package:paysense/shared/widgets/app_card.dart';

class LoansScreen extends ConsumerWidget {
  const LoansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loansAsync = ref.watch(loansProvider);
    final summary = ref.watch(loanSummaryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('Loans'),
        titleTextStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      body: SafeArea(
        child: loansAsync.when(
          data: (loans) {
            final sorted = loans.toList()
              ..sort((a, b) {
                if (a.isActive != b.isActive) {
                  return a.isActive ? -1 : 1;
                }
                return a.nextDueDate.compareTo(b.nextDueDate);
              });

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LoanSummaryCard(
                    totalLoans: summary.totalLoans,
                    activeLoans: summary.activeLoans,
                    closedLoans: summary.closedLoans,
                    outstandingBalance: summary.outstandingBalance,
                    totalEmiPerMonth: summary.totalEmiPerMonth,
                    totalInterest: summary.totalInterest,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Your loans',
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: () => _showForm(context, ref),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text('New loan'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (sorted.isEmpty)
                    AppCard(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No loans yet. Add a home, personal, car, or other '
                        'loan to start tracking EMIs.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    )
                  else
                    Column(
                      children: sorted
                          .map(
                            (loan) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: LoanCard(
                                loan: loan,
                                onEdit: () => _showForm(context, ref, loan: loan),
                                onDelete: () => _delete(context, ref, loan.id),
                                onPayEmi: () => _payEmi(context, ref, loan),
                                onClose: () => _close(context, ref, loan.id),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Unable to load loans right now.',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showForm(
    BuildContext context,
    WidgetRef ref, {
    Loan? loan,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return LoanFormSheet(
          loan: loan,
          onSave: (updated) async {
            if (loan == null) {
              await ref.read(loansProvider.notifier).addLoan(updated);
            } else {
              await ref.read(loansProvider.notifier).updateLoan(updated);
            }
            if (context.mounted) {
              Navigator.of(context).pop();
            }
          },
        );
      },
    );
  }

  Future<void> _payEmi(BuildContext context, WidgetRef ref, Loan loan) async {
    final confirmed = await PaymentConfirmationDialog.show(context, loan);
    if (confirmed) {
      await ref.read(loansProvider.notifier).markEmiPaid(loan.id);
    }
  }

  Future<void> _close(BuildContext context, WidgetRef ref, String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Close loan'),
        content: const Text(
          'Mark this loan as closed? Its outstanding balance will be set '
          'to zero and no further EMI reminders will be scheduled.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Close loan'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(loansProvider.notifier).closeLoan(id);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete loan'),
        content: const Text(
          'Are you sure you want to remove this loan? Past EMI payment '
          'records will not be affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(loansProvider.notifier).deleteLoan(id);
    }
  }
}
