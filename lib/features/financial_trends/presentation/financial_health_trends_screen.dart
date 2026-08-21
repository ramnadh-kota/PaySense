import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/core/routes/app_routes.dart';
import 'package:paysense/shared/providers/financial_health_trends_provider.dart';
import 'package:paysense/shared/utils/financial_health_trends_calculator.dart';
import 'package:paysense/shared/widgets/app_card.dart';

final _money = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

/// PHASE 15 — the Financial Health Trends screen. Every figure comes from
/// [financialHealthTrendsProvider] (→ [FinancialHealthTrendsCalculator]) —
/// this screen only formats, it never computes a trend itself.
class FinancialHealthTrendsScreen extends ConsumerWidget {
  const FinancialHealthTrendsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(financialHealthTrendsProvider);
    final period = ref.watch(financialHealthTrendsPeriodProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: const Text('Financial Health'),
      ),
      body: SafeArea(
        child: !result.hasSufficientData
            ? _EmptyState(monthsOfDataAvailable: result.monthsOfDataAvailable)
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'See how your finances are changing over time.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    _PeriodSelector(selected: period),
                    const SizedBox(height: 20),
                    _TrajectoryCard(result: result),
                    const SizedBox(height: 20),
                    _SectionTitle('Health Score Trend'),
                    const SizedBox(height: 8),
                    _ScoreTrendCard(scoreTrend: result.scoreTrend),
                    const SizedBox(height: 20),
                    _SectionTitle('Cash Flow Trend'),
                    const SizedBox(height: 8),
                    _CashFlowCard(series: result.monthlySeries),
                    const SizedBox(height: 20),
                    _SectionTitle('Savings Trend'),
                    const SizedBox(height: 8),
                    _SavingsTrendCard(savingsTrend: result.savingsTrend),
                    if (result.spendingBehaviorSignals.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _SectionTitle('Spending Behavior'),
                      const SizedBox(height: 8),
                      _SpendingBehaviorCard(signals: result.spendingBehaviorSignals),
                    ],
                    const SizedBox(height: 20),
                    _SectionTitle('Budget Trend'),
                    const SizedBox(height: 8),
                    _BudgetTrendCard(budgetTrend: result.budgetTrend),
                    const SizedBox(height: 20),
                    _SectionTitle('Debt Trend'),
                    const SizedBox(height: 8),
                    _DebtTrendCard(debtTrend: result.debtTrend),
                    const SizedBox(height: 20),
                    _SectionTitle('Goal Progress'),
                    const SizedBox(height: 8),
                    _GoalTrendCard(goalTrend: result.goalTrend),
                    const SizedBox(height: 20),
                    _SectionTitle('Emergency Fund'),
                    const SizedBox(height: 8),
                    _EmergencyFundTrendCard(efTrend: result.emergencyFundTrend),
                    if (result.keyInsights.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _SectionTitle('Key Insights'),
                      const SizedBox(height: 8),
                      _KeyInsightsCard(insights: result.keyInsights),
                    ],
                    const SizedBox(height: 20),
                    _WhatShouldIDoCard(),
                  ],
                ),
              ),
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

class _PeriodSelector extends ConsumerWidget {
  const _PeriodSelector({required this.selected});
  final TrendPeriod selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SegmentedButton<TrendPeriod>(
      segments: TrendPeriod.values
          .map((p) => ButtonSegment(value: p, label: Text(p.label)))
          .toList(),
      selected: {selected},
      onSelectionChanged: (selection) =>
          ref.read(financialHealthTrendsPeriodProvider.notifier).state = selection.first,
    );
  }
}

String _directionLabel(TrendDirection direction) {
  switch (direction) {
    case TrendDirection.improving:
      return 'Improving';
    case TrendDirection.declining:
      return 'Declining';
    case TrendDirection.stable:
      return 'Stable';
    case TrendDirection.insufficientData:
      return 'Not enough data yet';
  }
}

Color _directionColor(TrendDirection direction) {
  switch (direction) {
    case TrendDirection.improving:
      return AppColors.success;
    case TrendDirection.declining:
      return AppColors.danger;
    case TrendDirection.stable:
      return AppColors.textSecondary;
    case TrendDirection.insufficientData:
      return AppColors.textSecondary;
  }
}

class _TrendBadge extends StatelessWidget {
  const _TrendBadge({required this.direction});
  final TrendDirection direction;

  @override
  Widget build(BuildContext context) {
    final color = _directionColor(direction);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: AppColors.lightTeal, borderRadius: BorderRadius.circular(20)),
      child: Text(
        _directionLabel(direction),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _TrajectoryCard extends StatelessWidget {
  const _TrajectoryCard({required this.result});
  final FinancialHealthTrendResult result;

  (String, String) _copyFor(OverallTrajectory trajectory) {
    switch (trajectory) {
      case OverallTrajectory.stronglyImproving:
        return ("You're improving", 'Your financial health has strongly improved recently.');
      case OverallTrajectory.improving:
        return ("You're improving", 'Your financial health has improved recently.');
      case OverallTrajectory.stable:
        return ("You're steady", 'Your financial health has stayed roughly the same recently.');
      case OverallTrajectory.mixed:
        return ('Mixed signals', 'Some areas improved while others need attention.');
      case OverallTrajectory.declining:
        return ('Needs attention', 'Your financial health has declined recently.');
      case OverallTrajectory.insufficientData:
        return ('Keep going', "Keep using PaySense to unlock your financial trajectory.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final (title, subtitle) = _copyFor(result.trajectory);
    final score = result.scoreTrend;

    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
          if (score.hasSufficientData) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                _scoreStat(context, 'Current', score.currentScore),
                const SizedBox(width: 20),
                _scoreStat(context, 'Previous', score.previousScore),
                const SizedBox(width: 20),
                _scoreStat(context, 'Change', score.change, signed: true),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _scoreStat(BuildContext context, String label, int? value, {bool signed = false}) {
    final display = value == null ? '—' : (signed && value > 0 ? '+$value' : '$value');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
        Text(
          display,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _ScoreTrendCard extends StatelessWidget {
  const _ScoreTrendCard({required this.scoreTrend});
  final ScoreTrend scoreTrend;

  @override
  Widget build(BuildContext context) {
    if (!scoreTrend.hasSufficientData || scoreTrend.history.length < 2) {
      return const _InsufficientDataNote(
        message: 'Keep using PaySense for another month to see your health score trend.',
      );
    }

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 160,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: 100,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= scoreTrend.history.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            DateFormat('MMM').format(scoreTrend.history[index].month),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineTouchData: const LineTouchData(enabled: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      for (var i = 0; i < scoreTrend.history.length; i++)
                        FlSpot(i.toDouble(), scoreTrend.history[i].score.toDouble()),
                    ],
                    isCurved: true,
                    color: AppColors.primary,
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(show: true, color: AppColors.lightTeal),
                  ),
                ],
              ),
            ),
          ),
          if (scoreTrend.history.any((p) => p.isApproximated)) ...[
            const SizedBox(height: 8),
            Text(
              'Past months are approximated from available savings and budget history — PaySense does not '
              'store historical wallet, goal, or loan snapshots.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CashFlowCard extends StatelessWidget {
  const _CashFlowCard({required this.series});
  final List<MonthlyFinancials> series;

  @override
  Widget build(BuildContext context) {
    final active = series.where((m) => m.hasActivity).toList();
    if (active.isEmpty) {
      return const _InsufficientDataNote(message: 'Add some transactions to see your cash flow trend.');
    }
    final maxValue = series.fold<double>(
      0,
      (max, m) => [max, m.income, m.expense].reduce((a, b) => a > b ? a : b),
    );
    final maxY = maxValue <= 0 ? 100.0 : maxValue * 1.2;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        height: 180,
        child: BarChart(
          BarChartData(
            maxY: maxY,
            minY: 0,
            alignment: BarChartAlignment.spaceAround,
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            barTouchData: BarTouchData(enabled: false),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index < 0 || index >= series.length) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        DateFormat('MMM').format(series[index].month),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                      ),
                    );
                  },
                ),
              ),
            ),
            barGroups: [
              for (var i = 0; i < series.length; i++)
                BarChartGroupData(
                  x: i,
                  barsSpace: 4,
                  barRods: [
                    BarChartRodData(
                      toY: series[i].income,
                      color: AppColors.success,
                      width: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    BarChartRodData(
                      toY: series[i].expense,
                      color: AppColors.danger,
                      width: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SavingsTrendCard extends StatelessWidget {
  const _SavingsTrendCard({required this.savingsTrend});
  final SavingsTrend savingsTrend;

  @override
  Widget build(BuildContext context) {
    if (!savingsTrend.hasSufficientData) {
      return const _InsufficientDataNote(message: 'Add income transactions to see your savings-rate trend.');
    }

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _statColumn(context, 'Current', savingsTrend.currentSavingsRate),
              const SizedBox(width: 20),
              _statColumn(context, 'Average', savingsTrend.averageSavingsRate),
            ],
          ),
          const SizedBox(height: 10),
          _TrendBadge(direction: savingsTrend.direction),
          if (savingsTrend.bestMonth != null && savingsTrend.weakestMonth != null) ...[
            const SizedBox(height: 8),
            Text(
              'Best month: ${DateFormat('MMM yyyy').format(savingsTrend.bestMonth!)} '
              '(${savingsTrend.bestMonthRate?.toStringAsFixed(0)}%) · '
              'Weakest: ${DateFormat('MMM yyyy').format(savingsTrend.weakestMonth!)} '
              '(${savingsTrend.weakestMonthRate?.toStringAsFixed(0)}%)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statColumn(BuildContext context, String label, double? value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
        Text(
          value == null ? '—' : '${value.toStringAsFixed(0)}%',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _SpendingBehaviorCard extends StatelessWidget {
  const _SpendingBehaviorCard({required this.signals});
  final List<FinancialTrendSignal> signals;

  @override
  Widget build(BuildContext context) {
    final top = signals.take(4).toList();
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final signal in top) ...[
            Text(
              signal.title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              signal.explanation,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
            if (signal != top.last) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _BudgetTrendCard extends StatelessWidget {
  const _BudgetTrendCard({required this.budgetTrend});
  final BudgetTrend budgetTrend;

  @override
  Widget build(BuildContext context) {
    if (!budgetTrend.hasSufficientData) {
      return const _InsufficientDataNote(message: 'Create budgets to see your budget-adherence trend.');
    }
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _countStat(context, 'Within budget', budgetTrend.monthsWithinBudget, AppColors.success),
              _countStat(context, 'Near limit', budgetTrend.monthsNearLimit, AppColors.warning),
              _countStat(context, 'Over budget', budgetTrend.monthsOverBudget, AppColors.danger),
            ],
          ),
          const SizedBox(height: 10),
          _TrendBadge(direction: budgetTrend.direction),
        ],
      ),
    );
  }

  Widget _countStat(BuildContext context, String label, int count, Color color) {
    return Column(
      children: [
        Text(
          '$count',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: color),
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
      ],
    );
  }
}

class _DebtTrendCard extends StatelessWidget {
  const _DebtTrendCard({required this.debtTrend});
  final DebtTrend debtTrend;

  @override
  Widget build(BuildContext context) {
    if (!debtTrend.hasSufficientData) {
      return const _InsufficientDataNote(message: 'No loans recorded yet.');
    }
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Outstanding: ${_money.format(debtTrend.currentOutstanding)}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Paid down so far: ${_money.format(debtTrend.totalPaidDown)} across '
            '${debtTrend.activeLoanCount} active loan${debtTrend.activeLoanCount == 1 ? '' : 's'}.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          _TrendBadge(direction: debtTrend.direction),
        ],
      ),
    );
  }
}

class _GoalTrendCard extends StatelessWidget {
  const _GoalTrendCard({required this.goalTrend});
  final GoalTrend goalTrend;

  @override
  Widget build(BuildContext context) {
    if (goalTrend.totalGoals == 0) {
      return const _InsufficientDataNote(message: 'No goals set yet.');
    }
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Text(
        'You have ${goalTrend.goalsOnTrack} goal${goalTrend.goalsOnTrack == 1 ? '' : 's'} on track and '
        '${goalTrend.goalsAtRisk} that need${goalTrend.goalsAtRisk == 1 ? 's' : ''} attention'
        '${goalTrend.goalsCompleted > 0 ? ' (${goalTrend.goalsCompleted} completed)' : ''}.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary),
      ),
    );
  }
}

class _EmergencyFundTrendCard extends StatelessWidget {
  const _EmergencyFundTrendCard({required this.efTrend});
  final EmergencyFundTrend efTrend;

  @override
  Widget build(BuildContext context) {
    if (!efTrend.isConfigured) {
      return const _InsufficientDataNote(message: "Emergency-fund tracking isn't configured yet.");
    }
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_money.format(efTrend.current ?? 0)} of ${_money.format(efTrend.target ?? 0)}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: ((efTrend.progressPercent ?? 0) / 100).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: AppColors.surfaceVariant,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _KeyInsightsCard extends StatelessWidget {
  const _KeyInsightsCard({required this.insights});
  final List<FinancialTrendSignal> insights;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final insight in insights) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  insight.severity == SignalSeverity.high ? Icons.warning_amber_rounded : Icons.insights_rounded,
                  size: 16,
                  color: insight.severity == SignalSeverity.high ? AppColors.danger : AppColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    insight.explanation,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
            if (insight != insights.last) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _WhatShouldIDoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What should I do?',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'See your prioritized actions, full financial plan, or ask the AI Assistant.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: () => Navigator.of(context).pushNamed(AppRoutes.dashboard),
                child: const Text('Financial Actions'),
              ),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pushNamed(AppRoutes.financialPlanning),
                child: const Text('Financial Planning'),
              ),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pushNamed(AppRoutes.aiCoach),
                child: const Text('Ask AI'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InsufficientDataNote extends StatelessWidget {
  const _InsufficientDataNote({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      color: AppColors.surfaceVariant,
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: AppColors.textSecondary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.monthsOfDataAvailable});
  final int monthsOfDataAvailable;

  @override
  Widget build(BuildContext context) {
    final message = monthsOfDataAvailable == 0
        ? 'Add some transactions to start seeing your financial trends.'
        : 'Keep using PaySense for another month to unlock meaningful comparisons.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_graph_rounded, color: AppColors.primary, size: 48),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
