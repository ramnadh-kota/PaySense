import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/core/routes/app_routes.dart';
import 'package:paysense/shared/providers/recurring_money_provider.dart';
import 'package:paysense/shared/utils/recurring_money_aggregator.dart';
import 'package:paysense/shared/widgets/app_card.dart';

/// FEATURE — RECURRING PAYMENT / SUBSCRIPTION INTELLIGENCE. Read-only: no
/// action here modifies a transaction/subscription/bill/loan
/// automatically — every row only navigates to the existing screen that
/// already owns that data.
class RecurringMoneyScreen extends ConsumerWidget {
  const RecurringMoneyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(recurringMoneySummaryProvider);
    final upcoming = _upcomingPayments(summary);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('Recurring Money'),
        titleTextStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      body: SafeArea(
        child: summary.isEmpty
            ? _buildEmptyState(context)
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '₹${summary.totalMonthlyCost.toStringAsFixed(0)}/month in recurring commitments',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₹${summary.totalAnnualCost.toStringAsFixed(0)}/year',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  for (final insight in summary.insights) ...[
                    const SizedBox(height: 10),
                    _InsightBanner(text: insight),
                  ],
                  if (upcoming.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _SectionHeading('Upcoming Payments'),
                    for (final item in upcoming)
                      _RecurringRow(
                        title: item.title,
                        subtitle: _daysRemainingLabel(item.dueDate),
                        amount: item.amount,
                        isOverdue: item.dueDate.isBefore(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)),
                        onTap: () => Navigator.of(context).pushNamed(item.route),
                      ),
                  ],
                  if (summary.subscriptions.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _SectionHeading('Subscriptions'),
                    for (final s in summary.subscriptions)
                      _RecurringRow(
                        title: s.name,
                        subtitle: '${s.frequency} · next ${_dateLabel(s.nextDueDate)}',
                        amount: s.monthlyEquivalent,
                        isOverdue: s.isOverdue,
                        onTap: () => Navigator.of(context).pushNamed(AppRoutes.recurring),
                      ),
                  ],
                  if (summary.recurringBills.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _SectionHeading('Bills'),
                    for (final b in summary.recurringBills)
                      _RecurringRow(
                        title: b.title,
                        subtitle: '${b.frequency} · due ${_dateLabel(b.dueDate)}',
                        amount: b.amount,
                        isOverdue: b.isOverdue(DateTime.now()),
                        onTap: () => Navigator.of(context).pushNamed(AppRoutes.bills),
                      ),
                  ],
                  if (summary.emiLoans.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _SectionHeading('EMIs'),
                    for (final l in summary.emiLoans)
                      _RecurringRow(
                        title: l.loanName,
                        subtitle: '${l.lenderName} · next ${_dateLabel(l.nextDueDate)}',
                        amount: l.emiAmount,
                        isOverdue: false,
                        onTap: () => Navigator.of(context).pushNamed(AppRoutes.loans),
                      ),
                  ],
                ],
              ),
      ),
    );
  }

  String _dateLabel(DateTime date) => '${date.day}/${date.month}/${date.year}';

  /// Merges subscriptions/bills/EMIs into one chronological list by their
  /// existing due dates — display-only, doesn't recompute any cost figure
  /// (each item's [amount] is the same value already shown in its own
  /// section below). Capped so the dashboard-style summary doesn't turn
  /// into an unbounded list.
  List<_UpcomingItem> _upcomingPayments(RecurringMoneySummary summary) {
    final items = <_UpcomingItem>[
      for (final s in summary.subscriptions)
        _UpcomingItem(title: s.name, amount: s.monthlyEquivalent, dueDate: s.nextDueDate, route: AppRoutes.recurring),
      for (final b in summary.recurringBills)
        _UpcomingItem(title: b.title, amount: b.amount, dueDate: b.dueDate, route: AppRoutes.bills),
      for (final l in summary.emiLoans)
        _UpcomingItem(title: l.loanName, amount: l.emiAmount, dueDate: l.nextDueDate, route: AppRoutes.loans),
    ]..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return items.take(8).toList();
  }

  String _daysRemainingLabel(DateTime dueDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final days = due.difference(today).inDays;
    if (days < 0) return 'Overdue by ${-days} day${-days == 1 ? '' : 's'}';
    if (days == 0) return 'Today';
    if (days == 1) return 'Tomorrow';
    return 'In $days days';
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.autorenew_rounded, size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(
              'No recurring commitments yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Subscriptions, bills, and EMIs will show up here once you add them.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _UpcomingItem {
  const _UpcomingItem({required this.title, required this.amount, required this.dueDate, required this.route});
  final String title;
  final double amount;
  final DateTime dueDate;
  final String route;
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
      ),
    );
  }
}

class _InsightBanner extends StatelessWidget {
  const _InsightBanner({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
      child: Text(text, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textPrimary)),
    );
  }
}

class _RecurringRow extends StatelessWidget {
  const _RecurringRow({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.isOverdue,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final double amount;
  final bool isOverdue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                ],
              ),
            ),
            Text(
              '₹${amount.toStringAsFixed(0)}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: isOverdue ? AppColors.danger : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
