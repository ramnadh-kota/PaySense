import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/features/analytics/widgets/category_breakdown_chart.dart';
import 'package:paysense/features/analytics/widgets/income_expense_chart.dart';
import 'package:paysense/features/analytics/widgets/loan_outstanding_chart.dart';
import 'package:paysense/features/dashboard/widgets/summary_card.dart';
import 'package:paysense/shared/providers/analytics_provider.dart';
import 'package:paysense/shared/widgets/app_card.dart';
import 'package:paysense/shared/widgets/section_header.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(analyticsSummaryProvider);
    final loanAnalytics = ref.watch(loanAnalyticsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Analytics',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  SummaryCard(
                    title: 'Income',
                    value: '₹${summary.currentMonthIncome.toStringAsFixed(0)}',
                    icon: Icons.arrow_downward_rounded,
                    iconColor: AppColors.success,
                  ),
                  const SizedBox(width: 12),
                  SummaryCard(
                    title: 'Expenses',
                    value: '₹${summary.currentMonthExpense.toStringAsFixed(0)}',
                    icon: Icons.arrow_upward_rounded,
                    iconColor: AppColors.danger,
                  ),
                  const SizedBox(width: 12),
                  SummaryCard(
                    title: 'Savings rate',
                    value: '${summary.savingsRate.toStringAsFixed(0)}%',
                    icon: Icons.savings_rounded,
                    iconColor: AppColors.primary,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const SectionHeader(title: 'Income vs Expense'),
              const SizedBox(height: 16),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Last $analyticsTrendMonths months',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    IncomeExpenseChart(monthlyTotals: summary.monthlyTotals),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _LegendDot(color: AppColors.success, label: 'Income'),
                        const SizedBox(width: 16),
                        _LegendDot(color: AppColors.danger, label: 'Expense'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const SectionHeader(title: 'Spending by Category'),
              const SizedBox(height: 16),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'This month',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    CategoryBreakdownChart(
                      breakdown: summary.categoryBreakdown,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const SectionHeader(title: 'Loans Overview'),
              const SizedBox(height: 16),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StatLine(
                      label: 'Loan-to-asset ratio',
                      value: '${loanAnalytics.loanToAssetRatio.toStringAsFixed(0)}%',
                    ),
                    const SizedBox(height: 10),
                    _StatLine(
                      label: 'Interest paid so far',
                      value: '₹${loanAnalytics.totalInterestPaidEstimate.toStringAsFixed(0)}',
                    ),
                    const SizedBox(height: 10),
                    _StatLine(
                      label: 'Monthly EMI burden',
                      value:
                          '₹${loanAnalytics.monthlyEmiBurden.toStringAsFixed(0)} (${loanAnalytics.monthlyEmiBurdenPercentage.toStringAsFixed(0)}% of income)',
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Estimated outstanding balance trend',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    LoanOutstandingChart(trend: loanAnalytics.outstandingTrend),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatLine extends StatelessWidget {
  const _StatLine({required this.label, required this.value});

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

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
