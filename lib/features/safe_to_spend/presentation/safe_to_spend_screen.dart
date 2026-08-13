import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/shared/providers/safe_to_spend_provider.dart';
import 'package:paysense/shared/providers/user_profile_provider.dart';
import 'package:paysense/shared/utils/currency_formatter.dart';
import 'package:paysense/shared/utils/safe_to_spend_calculator.dart';
import 'package:paysense/shared/widgets/app_card.dart';

class SafeToSpendScreen extends ConsumerWidget {
  const SafeToSpendScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(safeToSpendProvider);
    final currencyCode = ref.watch(userProfileProvider).value?.currency.isNotEmpty == true
        ? ref.watch(userProfileProvider).value!.currency
        : 'INR';
    final currencyFormatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: CurrencyFormatter.symbolFor(currencyCode),
      decimalDigits: 0,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: const Text('Safe to Spend'),
      ),
      body: SafeArea(
        child: !result.hasSufficientData
            ? _EmptyState(
                icon: Icons.account_balance_wallet_outlined,
                message:
                    'Add your accounts to calculate your safe-to-spend amount.',
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                children: [
                  _HeroSection(result: result, currencyFormatter: currencyFormatter),
                  const SizedBox(height: 20),
                  _BreakdownSection(result: result, currencyFormatter: currencyFormatter),
                  const SizedBox(height: 20),
                  _CommitmentsSection(result: result, currencyFormatter: currencyFormatter),
                  if (result.hasSufficientData &&
                      !result.isShortfall &&
                      result.safeToSpend > 0) ...[
                    const SizedBox(height: 20),
                    _DailySpendingSection(result: result, currencyFormatter: currencyFormatter),
                  ],
                  const SizedBox(height: 20),
                  const _DisclaimerCard(),
                ],
              ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({required this.result, required this.currencyFormatter});

  final SafeToSpendResult result;
  final NumberFormat currencyFormatter;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(24),
      color: AppColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Safe to Spend',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 10),
          if (result.isShortfall) ...[
            Text(
              "You're ${currencyFormatter.format(result.shortfall)} short for upcoming commitments.",
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ] else ...[
            Text(
              currencyFormatter.format(result.safeToSpend),
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'You can comfortably spend up to this amount based on your '
              'current money and upcoming commitments.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white70,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Text(
            'Based on next ${result.windowDays} days',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _BreakdownSection extends StatelessWidget {
  const _BreakdownSection({required this.result, required this.currencyFormatter});

  final SafeToSpendResult result;
  final NumberFormat currencyFormatter;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BreakdownRow(
            label: 'Current money',
            value: currencyFormatter.format(result.availableMoney),
            valueColor: AppColors.textPrimary,
          ),
          const SizedBox(height: 10),
          _BreakdownRow(
            label: 'Upcoming commitments',
            value: '-${currencyFormatter.format(result.upcomingCommitments)}',
            valueColor: AppColors.danger,
          ),
          const SizedBox(height: 10),
          if (result.savingsIncluded)
            _BreakdownRow(
              label: 'Planned savings',
              value: '-${currencyFormatter.format(result.plannedSavings)}',
              valueColor: AppColors.danger,
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Planned savings',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  'Not included',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

class _CommitmentsSection extends StatelessWidget {
  const _CommitmentsSection({required this.result, required this.currencyFormatter});

  final SafeToSpendResult result;
  final NumberFormat currencyFormatter;

  @override
  Widget build(BuildContext context) {
    if (result.commitmentBreakdown.isEmpty) {
      return AppCard(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(Icons.celebration_rounded, color: AppColors.success),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "You're all caught up 🎉 No commitments due in the next "
                '${result.windowDays} days.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final bills = result.commitmentBreakdown
        .where((c) => c.type == SafeToSpendCommitmentType.bill)
        .toList();
    final emis = result.commitmentBreakdown
        .where((c) => c.type == SafeToSpendCommitmentType.emi)
        .toList();
    final recurring = result.commitmentBreakdown
        .where((c) => c.type == SafeToSpendCommitmentType.recurring)
        .toList();

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Upcoming commitments',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          if (bills.isNotEmpty) ...[
            const SizedBox(height: 14),
            _CommitmentGroup(
              title: 'Bills',
              items: bills,
              currencyFormatter: currencyFormatter,
            ),
          ],
          if (emis.isNotEmpty) ...[
            const SizedBox(height: 14),
            _CommitmentGroup(
              title: 'EMIs',
              items: emis,
              currencyFormatter: currencyFormatter,
            ),
          ],
          if (recurring.isNotEmpty) ...[
            const SizedBox(height: 14),
            _CommitmentGroup(
              title: 'Recurring payments',
              items: recurring,
              currencyFormatter: currencyFormatter,
            ),
          ],
        ],
      ),
    );
  }
}

class _CommitmentGroup extends StatelessWidget {
  const _CommitmentGroup({
    required this.title,
    required this.items,
    required this.currencyFormatter,
  });

  final String title;
  final List<SafeToSpendCommitment> items;
  final NumberFormat currencyFormatter;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        item.isOverdue
                            ? 'Overdue since ${_formatDate(item.dueDate)}'
                            : 'Due ${_formatDate(item.dueDate)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: item.isOverdue
                              ? AppColors.danger
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  currencyFormatter.format(item.amount),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DailySpendingSection extends StatelessWidget {
  const _DailySpendingSection({required this.result, required this.currencyFormatter});

  final SafeToSpendResult result;
  final NumberFormat currencyFormatter;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      color: AppColors.lightTeal,
      child: Row(
        children: [
          Icon(Icons.bolt_rounded, color: AppColors.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Suggested daily spending',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${currencyFormatter.format(result.dailySafeToSpend)}/day',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DisclaimerCard extends StatelessWidget {
  const _DisclaimerCard();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Keep in mind: this is an app-generated planning estimate based on '
      'the financial information currently recorded in PaySense, not '
      'financial advice.',
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: AppColors.textSecondary,
        fontStyle: FontStyle.italic,
      ),
    );
  }
}

String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';
