import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/core/routes/app_routes.dart';
import 'package:paysense/features/dashboard/widgets/financial_health_card.dart'
    show financialHealthStatusColor;
import 'package:paysense/features/transactions/presentation/add_expense_screen.dart';
import 'package:paysense/features/transactions/presentation/add_income_screen.dart';
import 'package:paysense/shared/providers/monthly_review_provider.dart';
import 'package:paysense/shared/providers/transaction_provider.dart';
import 'package:paysense/shared/providers/user_profile_provider.dart';
import 'package:paysense/shared/utils/currency_formatter.dart';
import 'package:paysense/shared/utils/financial_health_calculator.dart'
    show financialHealthStatusLabel;
import 'package:paysense/shared/utils/monthly_review_calculator.dart';
import 'package:paysense/shared/widgets/app_card.dart';

class MonthlyReviewScreen extends ConsumerWidget {
  const MonthlyReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final review = ref.watch(monthlyReviewProvider);
    final months = ref.watch(availableReviewMonthsProvider);
    final selectedMonth = ref.watch(monthlyReviewSelectedMonthProvider);
    final hasAnyTransactions =
        (ref.watch(transactionsProvider).value ?? const []).isNotEmpty;
    final currencyCode = ref.watch(userProfileProvider).value?.currency ?? 'INR';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: const Text('Monthly Review'),
      ),
      body: SafeArea(
        child: !hasAnyTransactions
            ? const _GlobalEmptyState()
            : ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                children: [
                  _MonthSelector(
                    months: months,
                    selectedMonth: selectedMonth,
                    onSelected: (month) => ref
                        .read(monthlyReviewSelectedMonthProvider.notifier)
                        .state = month,
                  ),
                  const SizedBox(height: 20),
                  if (!review.hasSufficientData)
                    AppCard(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'Not enough data for this month yet.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    )
                  else ...[
                    _OverallSummary(review: review, currencyCode: currencyCode),
                    const SizedBox(height: 20),
                    _ComparisonSection(review: review),
                    const SizedBox(height: 20),
                    _SpendingBreakdown(review: review, currencyCode: currencyCode),
                    const SizedBox(height: 20),
                    _BudgetPerformance(review: review),
                    const SizedBox(height: 20),
                    _GoalSection(review: review, currencyCode: currencyCode),
                    const SizedBox(height: 20),
                    _BillsAndLoans(review: review, currencyCode: currencyCode),
                    const SizedBox(height: 20),
                    _FinancialHealthSection(review: review),
                    const SizedBox(height: 20),
                    _InsightsSection(review: review),
                    const SizedBox(height: 20),
                    _WentWellAndImprove(review: review),
                    const SizedBox(height: 20),
                    _Scorecard(review: review, currencyCode: currencyCode),
                  ],
                ],
              ),
      ),
    );
  }
}

class _MonthSelector extends StatelessWidget {
  const _MonthSelector({
    required this.months,
    required this.selectedMonth,
    required this.onSelected,
  });

  final List<DateTime> months;
  final DateTime selectedMonth;
  final ValueChanged<DateTime> onSelected;

  static const _labels = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: months.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final month = months[index];
          final isSelected =
              month.year == selectedMonth.year && month.month == selectedMonth.month;
          final label = index == 0
              ? 'This month'
              : index == 1
              ? 'Last month'
              : '${_labels[month.month - 1]} ${month.year}';
          return ChoiceChip(
            label: Text(label),
            selected: isSelected,
            onSelected: (_) => onSelected(month),
            selectedColor: AppColors.lightTeal,
            backgroundColor: AppColors.surface,
            labelStyle: TextStyle(
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
            side: BorderSide(
              color: isSelected ? AppColors.primary : AppColors.divider,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          );
        },
      ),
    );
  }
}

class _OverallSummary extends StatelessWidget {
  const _OverallSummary({required this.review, required this.currencyCode});

  final MonthlyReviewResult review;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      color: AppColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            review.monthLabel,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SummaryStat(
                  label: 'Income',
                  value: CurrencyFormatter.format(review.income, currencyCode),
                ),
              ),
              Expanded(
                child: _SummaryStat(
                  label: 'Expenses',
                  value: CurrencyFormatter.format(review.expenses, currencyCode),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _SummaryStat(
                  label: 'Savings',
                  value: CurrencyFormatter.format(review.savings, currencyCode),
                ),
              ),
              Expanded(
                child: _SummaryStat(
                  label: 'Savings rate',
                  value: '${review.savingsRate.round()}%',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.white70),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ComparisonSection extends StatelessWidget {
  const _ComparisonSection({required this.review});

  final MonthlyReviewResult review;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'vs Last Month',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _ComparisonRow(label: 'Income', comparison: review.comparisons.income),
          const SizedBox(height: 8),
          _ComparisonRow(label: 'Expenses', comparison: review.comparisons.expenses),
          const SizedBox(height: 8),
          _ComparisonRow(label: 'Savings', comparison: review.comparisons.savings),
        ],
      ),
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  const _ComparisonRow({required this.label, required this.comparison});

  final String label;
  final MonthlyReviewComparison comparison;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary),
          ),
        ),
        if (!comparison.hasData)
          Text(
            'Not enough historical data',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          )
        else
          Row(
            children: [
              Icon(
                comparison.changePercent! >= 0
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                size: 16,
                color: comparison.changePercent! >= 0
                    ? AppColors.success
                    : AppColors.danger,
              ),
              Text(
                '${comparison.changePercent!.abs().round()}%',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: comparison.changePercent! >= 0
                      ? AppColors.success
                      : AppColors.danger,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _SpendingBreakdown extends StatelessWidget {
  const _SpendingBreakdown({required this.review, required this.currencyCode});

  final MonthlyReviewResult review;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Spending Breakdown',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          if (review.topCategories.isEmpty)
            Text(
              'No expenses recorded this month.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            )
          else
            ...review.topCategories.map(
              (category) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        category.categoryId,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      CurrencyFormatter.format(category.amount, currencyCode),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (review.largestTransaction != null) ...[
            const Divider(height: 24, color: AppColors.divider),
            Text(
              'Largest transaction',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    review.largestTransaction!.title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  CurrencyFormatter.format(
                    review.largestTransaction!.amount,
                    currencyCode,
                  ),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _BudgetPerformance extends StatelessWidget {
  const _BudgetPerformance({required this.review});

  final MonthlyReviewResult review;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      onTap: () => Navigator.of(context).pushNamed(AppRoutes.budget),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Budget Health',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          if (!review.budgetStatus.hasBudgets)
            Text(
              'Set a budget to start measuring your spending discipline.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            )
          else
            Row(
              children: [
                _BudgetStatusChip(
                  count: review.budgetStatus.onTrack,
                  label: 'on track',
                  color: AppColors.success,
                ),
                const SizedBox(width: 10),
                _BudgetStatusChip(
                  count: review.budgetStatus.nearLimit,
                  label: 'near limit',
                  color: AppColors.warning,
                ),
                const SizedBox(width: 10),
                _BudgetStatusChip(
                  count: review.budgetStatus.exceeded,
                  label: 'exceeded',
                  color: AppColors.danger,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _BudgetStatusChip extends StatelessWidget {
  const _BudgetStatusChip({
    required this.count,
    required this.label,
    required this.color,
  });

  final int count;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            '$count',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _GoalSection extends StatelessWidget {
  const _GoalSection({required this.review, required this.currencyCode});

  final MonthlyReviewResult review;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final goal = review.relevantGoal;
    return AppCard(
      padding: const EdgeInsets.all(20),
      onTap: () => Navigator.of(context).pushNamed(AppRoutes.goals),
      child: goal == null
          ? Text(
              'Create a savings goal to track progress.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🎯 ${goal.title}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${CurrencyFormatter.format(goal.currentAmount, currencyCode)} saved toward ${CurrencyFormatter.format(goal.targetAmount, currencyCode)}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: (goal.progressPercentage / 100).clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: AppColors.background,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${goal.progressPercentage.clamp(0, 100).toStringAsFixed(0)}% complete',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
    );
  }
}

class _BillsAndLoans extends StatelessWidget {
  const _BillsAndLoans({required this.review, required this.currencyCode});

  final MonthlyReviewResult review;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bills & Loans',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          if (!review.billStatus.hasBills)
            Text(
              'No bills tracked yet.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            )
          else
            Text(
              '${review.billStatus.paidThisMonth} paid this month · '
              '${review.billStatus.overdueNow} overdue · '
              '${review.billStatus.upcomingCount} upcoming',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          if (review.loanSummary.activeLoans > 0) ...[
            const Divider(height: 24, color: AppColors.divider),
            Row(
              children: [
                Expanded(
                  child: _SummaryStatDark(
                    label: 'Monthly EMI',
                    value: CurrencyFormatter.format(
                      review.loanSummary.totalEmiPerMonth,
                      currencyCode,
                    ),
                  ),
                ),
                Expanded(
                  child: _SummaryStatDark(
                    label: 'Outstanding',
                    value: CurrencyFormatter.format(
                      review.loanSummary.outstandingBalance,
                      currencyCode,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryStatDark extends StatelessWidget {
  const _SummaryStatDark({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 2),
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

class _FinancialHealthSection extends StatelessWidget {
  const _FinancialHealthSection({required this.review});

  final MonthlyReviewResult review;

  @override
  Widget build(BuildContext context) {
    final health = review.financialHealth;
    return AppCard(
      padding: const EdgeInsets.all(20),
      onTap: () => Navigator.of(context).pushNamed(AppRoutes.financialHealth),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Financial Health',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Current status',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          if (health.hasSufficientData) ...[
            Text(
              '${health.overallScore}/100',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: financialHealthStatusColor(
                  health.status,
                ).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                financialHealthStatusLabel(health.status),
                style: TextStyle(
                  color: financialHealthStatusColor(health.status),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ] else
            Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
        ],
      ),
    );
  }
}

class _InsightsSection extends StatelessWidget {
  const _InsightsSection({required this.review});

  final MonthlyReviewResult review;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Monthly Insights',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < review.insights.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            Text(
              '•  ${review.insights[i]}',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary),
            ),
          ],
        ],
      ),
    );
  }
}

class _WentWellAndImprove extends StatelessWidget {
  const _WentWellAndImprove({required this.review});

  final MonthlyReviewResult review;

  @override
  Widget build(BuildContext context) {
    if (review.whatWentWell.isEmpty && review.whatToImprove.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (review.whatWentWell.isNotEmpty)
          AppCard(
            padding: const EdgeInsets.all(20),
            color: AppColors.lightTeal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'What Went Well',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                for (final item in review.whatWentWell)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '✓ $item',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        if (review.whatWentWell.isNotEmpty && review.whatToImprove.isNotEmpty)
          const SizedBox(height: 12),
        if (review.whatToImprove.isNotEmpty)
          AppCard(
            padding: const EdgeInsets.all(20),
            color: AppColors.softCoral,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'What To Improve',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                for (final item in review.whatToImprove)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '→ $item',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Scorecard extends StatelessWidget {
  const _Scorecard({required this.review, required this.currencyCode});

  final MonthlyReviewResult review;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Monthly Scorecard',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            runSpacing: 12,
            children: [
              _ScorecardCell(
                label: 'Income',
                value: CurrencyFormatter.format(review.income, currencyCode),
              ),
              _ScorecardCell(
                label: 'Expenses',
                value: CurrencyFormatter.format(review.expenses, currencyCode),
              ),
              _ScorecardCell(
                label: 'Savings',
                value: CurrencyFormatter.format(review.savings, currencyCode),
              ),
              _ScorecardCell(
                label: 'Savings Rate',
                value: '${review.savingsRate.round()}%',
              ),
              _ScorecardCell(
                label: 'Financial Health',
                value: review.financialHealth.hasSufficientData
                    ? '${review.financialHealth.overallScore}/100'
                    : '—',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScorecardCell extends StatelessWidget {
  const _ScorecardCell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
      ),
    );
  }
}

class _GlobalEmptyState extends StatelessWidget {
  const _GlobalEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insights_rounded, size: 56, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(
              'Your monthly review will appear here once you start '
              'tracking your finances.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AddExpenseScreen()),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('Add expense'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AddIncomeScreen()),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('Add income'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRoutes.budget),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('Create budget'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
