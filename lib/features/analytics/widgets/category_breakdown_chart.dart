import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/shared/providers/analytics_provider.dart';

/// A brand-neutral categorical palette cycled through for pie slices/legend
/// dots so each category gets a stable, distinct color regardless of name.
const List<Color> _paletteColors = <Color>[
  AppColors.primary,
  AppColors.secondary,
  AppColors.warning,
  AppColors.danger,
  AppColors.success,
  Color(0xFF0EA5E9),
  Color(0xFFEC4899),
  Color(0xFF8B5CF6),
];

/// Donut chart with a category legend for the current month's expense
/// breakdown.
class CategoryBreakdownChart extends StatelessWidget {
  const CategoryBreakdownChart({super.key, required this.breakdown});

  final List<CategoryBreakdown> breakdown;

  @override
  Widget build(BuildContext context) {
    if (breakdown.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'No expenses recorded this month yet.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 180,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 48,
              sections: [
                for (var i = 0; i < breakdown.length; i++)
                  PieChartSectionData(
                    value: breakdown[i].amount,
                    color: _paletteColors[i % _paletteColors.length],
                    radius: 36,
                    showTitle: false,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Column(
          children: [
            for (var i = 0; i < breakdown.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _paletteColors[i % _paletteColors.length],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        breakdown[i].categoryId,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(color: AppColors.textPrimary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '₹${breakdown[i].amount.toStringAsFixed(0)}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 44,
                      child: Text(
                        '${breakdown[i].percentage.toStringAsFixed(0)}%',
                        textAlign: TextAlign.right,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}
