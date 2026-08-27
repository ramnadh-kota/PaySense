import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/shared/models/fun_group_expense.dart';
import 'package:paysense/shared/providers/fun_funds_provider.dart';
import 'package:paysense/shared/providers/fun_group_expense_provider.dart';
import 'package:paysense/shared/providers/user_profile_provider.dart';
import 'package:paysense/shared/utils/currency_formatter.dart';
import 'package:paysense/shared/utils/fun_funds_calculator.dart';
import 'package:paysense/shared/widgets/app_card.dart';

import 'add_group_expense_screen.dart';

class FunFundsScreen extends ConsumerWidget {
  const FunFundsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(funFundsProvider);
    final expensesAsync = ref.watch(funGroupExpensesProvider);
    final profile = ref.watch(userProfileProvider).value;
    final currencyCode = profile?.currency.isNotEmpty == true
        ? profile!.currency
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
        title: const Text('Fun Funds'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AddGroupExpenseScreen()),
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Group Expense'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 96),
          children: [
            _FunFundsSummaryCard(
              result: result,
              currencyFormatter: currencyFormatter,
            ),
            const SizedBox(height: 24),
            Text(
              'Friends & Group Expenses',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            expensesAsync.when(
              data: (expenses) => expenses.isEmpty
                  ? AppCard(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        "Log a dinner, trip, or movie you're splitting with "
                        'friends to track who owes what.',
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                    )
                  : Column(
                      children: [
                        for (final expense in expenses) ...[
                          _GroupExpenseCard(
                            expense: expense,
                            currencyFormatter: currencyFormatter,
                          ),
                          const SizedBox(height: 12),
                        ],
                      ],
                    ),
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (_, _) => Text(
                'Unable to load group expenses right now.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FunFundsSummaryCard extends StatelessWidget {
  const _FunFundsSummaryCard({
    required this.result,
    required this.currencyFormatter,
  });

  final FunFundsResult result;
  final NumberFormat currencyFormatter;

  @override
  Widget build(BuildContext context) {
    if (!result.hasSufficientData) {
      return AppCard(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Not enough data yet. Add a wallet and some transactions so '
          'PaySense can work out what you can comfortably enjoy this month.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
      );
    }

    final remaining = result.remaining;
    final available = result.monthlyAvailable;
    final utilization = result.utilizationPercent.clamp(0, 999);

    return AppCard(
      padding: const EdgeInsets.all(24),
      color: AppColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FUN FUND REMAINING',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            currencyFormatter.format(remaining),
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'This is what you can comfortably enjoy this month.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: (utilization / 100).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "You've used ${utilization.toStringAsFixed(0)}% of this month's "
            'Fun Fund of ${currencyFormatter.format(available)}.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _FunFundsStat(
                  label: 'Daily',
                  value: currencyFormatter.format(result.dailyBudget),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _FunFundsStat(
                  label: 'Weekly',
                  value: currencyFormatter.format(result.weeklyBudget),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FunFundsStat extends StatelessWidget {
  const _FunFundsStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupExpenseCard extends ConsumerWidget {
  const _GroupExpenseCard({
    required this.expense,
    required this.currencyFormatter,
  });

  final FunGroupExpense expense;
  final NumberFormat currencyFormatter;

  IconData get _icon {
    switch (expense.category) {
      case FunGroupExpenseCategory.dinner:
        return Icons.restaurant_rounded;
      case FunGroupExpenseCategory.movie:
        return Icons.movie_rounded;
      case FunGroupExpenseCategory.trip:
        return Icons.flight_takeoff_rounded;
      case FunGroupExpenseCategory.weekend:
        return Icons.weekend_rounded;
      case FunGroupExpenseCategory.event:
        return Icons.celebration_rounded;
      case FunGroupExpenseCategory.other:
        return Icons.receipt_long_rounded;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final others = expense.participants
        .where((p) => p.id != expense.paidByParticipantId)
        .toList();

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.lightTeal,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(_icon, color: AppColors.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      expense.title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${expense.participants.length} people · '
                      '${_formatDate(expense.date)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                currencyFormatter.format(expense.totalAmount),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            expense.iPaid
                ? 'You paid ${currencyFormatter.format(expense.totalAmount)} · '
                      'your share ${currencyFormatter.format(expense.myShare)}'
                : 'You owe ${currencyFormatter.format(expense.myShare)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          if (expense.iPaid && expense.othersOweMe > 0) ...[
            const SizedBox(height: 2),
            Text(
              'Others owe you ${currencyFormatter.format(expense.othersOweMe)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.success,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (expense.isFullySettled)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 14,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Settled up',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
          else if (expense.iPaid && others.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: others.map((p) {
                return FilterChip(
                  label: Text(
                    '${p.name} · ${currencyFormatter.format(p.shareAmount)}',
                  ),
                  selected: p.isSettled,
                  onSelected: (_) => ref
                      .read(funGroupExpensesProvider.notifier)
                      .toggleSettled(expense.id, p.id),
                  avatar: Icon(
                    p.isSettled
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 16,
                    color: p.isSettled ? AppColors.success : AppColors.textSecondary,
                  ),
                  selectedColor: AppColors.success.withValues(alpha: 0.12),
                );
              }).toList(),
            ),
          ] else if (!expense.iPaid) ...[
            const SizedBox(height: 8),
            FilterChip(
              label: Text(
                _me(expense)?.isSettled == true
                    ? 'You paid them back'
                    : "Mark as paid back",
              ),
              selected: _me(expense)?.isSettled ?? false,
              onSelected: (_) => ref
                  .read(funGroupExpensesProvider.notifier)
                  .toggleSettled(
                    expense.id,
                    funGroupExpenseMeParticipantId,
                  ),
              avatar: Icon(
                _me(expense)?.isSettled == true
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 16,
                color: _me(expense)?.isSettled == true
                    ? AppColors.success
                    : AppColors.textSecondary,
              ),
              selectedColor: AppColors.success.withValues(alpha: 0.12),
            ),
          ],
        ],
      ),
    );
  }

  FunGroupParticipant? _me(FunGroupExpense expense) {
    for (final p in expense.participants) {
      if (p.id == funGroupExpenseMeParticipantId) {
        return p;
      }
    }
    return null;
  }

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';
}
