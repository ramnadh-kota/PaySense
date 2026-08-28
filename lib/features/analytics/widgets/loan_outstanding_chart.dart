import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/shared/providers/analytics_provider.dart';

/// Line chart of the estimated total outstanding loan balance across the
/// trailing [analyticsTrendMonths] months.
class LoanOutstandingChart extends StatelessWidget {
  const LoanOutstandingChart({super.key, required this.trend});

  final List<MonthlyOutstanding> trend;

  @override
  Widget build(BuildContext context) {
    final maxValue = trend.fold<double>(
      0,
      (max, month) => month.outstanding > max ? month.outstanding : max,
    );
    final maxY = maxValue <= 0 ? 100.0 : maxValue * 1.2;

    return SizedBox(
      height: 160,
      child: LineChart(
        LineChartData(
          maxY: maxY,
          minY: 0,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
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
                // Without an explicit interval, fl_chart auto-picks a
                // fractional step (e.g. 0.5) for this small 0..5 range,
                // calling getTitlesWidget at non-integer x values whose
                // .toInt() truncates to the SAME month index twice in a
                // row — the duplicated "Mar Mar Apr Apr..." labels seen
                // on-device. One label per data point, exactly once.
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= trend.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      DateFormat('MMM').format(trend[index].month),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var i = 0; i < trend.length; i++)
                  FlSpot(i.toDouble(), trend[i].outstanding),
              ],
              isCurved: true,
              color: AppColors.warning,
              barWidth: 3,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.warning.withValues(alpha: 0.12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
