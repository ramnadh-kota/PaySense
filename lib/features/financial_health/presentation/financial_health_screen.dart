import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/features/dashboard/widgets/financial_health_card.dart'
    show financialHealthStatusColor;
import 'package:paysense/shared/providers/analytics_provider.dart';
import 'package:paysense/shared/providers/financial_health_provider.dart';
import 'package:paysense/shared/providers/user_profile_provider.dart';
import 'package:paysense/shared/utils/currency_formatter.dart';
import 'package:paysense/shared/utils/financial_health_calculator.dart';
import 'package:paysense/shared/widgets/app_card.dart';

class FinancialHealthScreen extends ConsumerWidget {
  const FinancialHealthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(financialHealthProvider);
    final analytics = ref.watch(analyticsSummaryProvider);
    final currencyCode = ref.watch(userProfileProvider).value?.currency ?? 'INR';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: const Text('Financial Health'),
      ),
      body: SafeArea(
        child: !health.hasSufficientData
            ? _EmptyState()
            : ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                children: [
                  _ScoreHero(health: health),
                  const SizedBox(height: 16),
                  Text(
                    'App-generated wellness indicator based on your PaySense data — not a credit score.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _SectionTitle('Breakdown'),
                  const SizedBox(height: 8),
                  AppCard(
                    child: Column(
                      children: [
                        _ComponentBar(label: 'Savings', score: health.components.savings),
                        const SizedBox(height: 14),
                        _ComponentBar(label: 'Budget', score: health.components.budget),
                        const SizedBox(height: 14),
                        _ComponentBar(label: 'Goals', score: health.components.goals),
                        const SizedBox(height: 14),
                        _ComponentBar(label: 'Debt', score: health.components.debt),
                        const SizedBox(height: 14),
                        _ComponentBar(label: 'Payments', score: health.components.payments),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _SectionTitle('This Month'),
                  const SizedBox(height: 8),
                  AppCard(
                    child: Row(
                      children: [
                        _SummaryStat(
                          label: 'Income',
                          value: CurrencyFormatter.format(
                            analytics.currentMonthIncome,
                            currencyCode,
                          ),
                          color: AppColors.success,
                        ),
                        _SummaryStat(
                          label: 'Expenses',
                          value: CurrencyFormatter.format(
                            analytics.currentMonthExpense,
                            currencyCode,
                          ),
                          color: AppColors.danger,
                        ),
                        _SummaryStat(
                          label: 'Savings rate',
                          value: '${analytics.savingsRate.round()}%',
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _SectionTitle('Comparisons'),
                  const SizedBox(height: 8),
                  AppCard(
                    child: Column(
                      children: [
                        _ComparisonRow(
                          label: 'Spending this week vs last week',
                          comparison: health.comparisons.weeklySpending,
                        ),
                        Divider(height: 24, color: AppColors.divider),
                        _ComparisonRow(
                          label: 'Income this month vs last month',
                          comparison: health.comparisons.monthlyIncome,
                        ),
                        Divider(height: 24, color: AppColors.divider),
                        _ComparisonRow(
                          label: 'Expenses this month vs last month',
                          comparison: health.comparisons.monthlyExpense,
                        ),
                        Divider(height: 24, color: AppColors.divider),
                        _ComparisonRow(
                          label: 'Savings this month vs last month',
                          comparison: health.comparisons.monthlySavings,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _SectionTitle('Smart Insights'),
                  const SizedBox(height: 8),
                  ...health.insights.map(
                    (insight) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _InsightTile(insight: insight),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SectionTitle('Recommendations'),
                  const SizedBox(height: 8),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < health.recommendations.length; i++) ...[
                          if (i > 0) const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.check_circle_outline_rounded,
                                size: 18,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  health.recommendations[i],
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(color: AppColors.textPrimary),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.favorite_border_rounded, size: 56, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(
              'Not enough data yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Add a few transactions and PaySense will start scoring your Financial Health.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreHero extends StatelessWidget {
  const _ScoreHero({required this.health});

  final FinancialHealthResult health;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(24),
      color: AppColors.primary,
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${health.overallScore}',
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'out of 100',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.white70),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              financialHealthStatusLabel(health.status),
              style: TextStyle(
                color: financialHealthStatusColor(health.status),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _ComponentBar extends StatelessWidget {
  const _ComponentBar({required this.label, required this.score});

  final String label;
  final int score;

  Color get _color {
    if (score >= 75) return AppColors.success;
    if (score >= 40) return AppColors.warning;
    return AppColors.danger;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '$score',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: score / 100,
            minHeight: 8,
            backgroundColor: AppColors.background,
            valueColor: AlwaysStoppedAnimation<Color>(_color),
          ),
        ),
      ],
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  const _ComparisonRow({required this.label, required this.comparison});

  final String label;
  final FinancialHealthComparison comparison;

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
            'Not enough data yet',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          )
        else
          Text(
            '${comparison.changePercent! >= 0 ? '+' : ''}${comparison.changePercent!.round()}%',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: comparison.changePercent! >= 0
                  ? AppColors.success
                  : AppColors.danger,
            ),
          ),
      ],
    );
  }
}

class _InsightTile extends StatelessWidget {
  const _InsightTile({required this.insight});

  final FinancialInsight insight;

  @override
  Widget build(BuildContext context) {
    final color = switch (insight.type) {
      FinancialInsightType.positive => AppColors.success,
      FinancialInsightType.tip => AppColors.primary,
      FinancialInsightType.warning => AppColors.accent,
    };
    final icon = switch (insight.type) {
      FinancialInsightType.positive => Icons.emoji_events_rounded,
      FinancialInsightType.tip => Icons.lightbulb_outline_rounded,
      FinancialInsightType.warning => Icons.warning_amber_rounded,
    };
    final background = switch (insight.type) {
      FinancialInsightType.warning => AppColors.softCoral,
      _ => AppColors.lightTeal,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              insight.message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
