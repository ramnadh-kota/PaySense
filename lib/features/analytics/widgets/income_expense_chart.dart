import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/shared/providers/analytics_provider.dart';

/// Grouped bar chart comparing income and expense for each of the trailing
/// [analyticsTrendMonths] months.
class IncomeExpenseChart extends StatelessWidget {
  const IncomeExpenseChart({super.key, required this.monthlyTotals});

  final List<MonthlyTotal> monthlyTotals;

  @override
  Widget build(BuildContext context) {
    final maxValue = monthlyTotals.fold<double>(
      0,
      (max, month) => [max, month.income, month.expense].reduce(
        (a, b) => a > b ? a : b,
      ),
    );
    final maxY = maxValue <= 0 ? 100.0 : maxValue * 1.2;

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          maxY: maxY,
          minY: 0,
          alignment: BarChartAlignment.spaceAround,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= monthlyTotals.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      DateFormat('MMM').format(monthlyTotals[index].month),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < monthlyTotals.length; i++)
              BarChartGroupData(
                x: i,
                barsSpace: 4,
                barRods: [
                  BarChartRodData(
                    toY: monthlyTotals[i].income,
                    color: AppColors.success,
                    width: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  BarChartRodData(
                    toY: monthlyTotals[i].expense,
                    color: AppColors.danger,
                    width: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
