import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/core/routes/app_routes.dart';
import 'package:paysense/shared/providers/cash_flow_provider.dart';
import 'package:paysense/shared/widgets/app_card.dart';

/// Compact Dashboard entry point for the Cash Flow calendar — a quick
/// "what's coming" glance, with the full calendar one tap away on
/// [AppRoutes.cashFlow].
class CashFlowCard extends ConsumerWidget {
  const CashFlowCard({super.key, required this.currencyFormatter});

  final NumberFormat currencyFormatter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(cashFlowNext30DaysSummaryProvider);

    return AppCard(
      onTap: () => Navigator.of(context).pushNamed(AppRoutes.cashFlow),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'CASH FLOW',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Next 30 days',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          if (!summary.hasActivity)
            Text(
              'Start tracking to see your cash flow.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: _FlowStat(
                    icon: Icons.arrow_downward_rounded,
                    label: 'Incoming',
                    value: currencyFormatter.format(summary.upcomingIncome),
                    color: AppColors.primary,
                  ),
                ),
                Expanded(
                  child: _FlowStat(
                    icon: Icons.arrow_upward_rounded,
                    label: 'Outgoing',
                    value: currencyFormatter.format(summary.upcomingExpense),
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 10),
          Text(
            'View calendar →',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FlowStat extends StatelessWidget {
  const _FlowStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
