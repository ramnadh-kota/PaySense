import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/core/routes/app_routes.dart';
import 'package:paysense/shared/providers/financial_health_provider.dart';
import 'package:paysense/shared/utils/financial_health_calculator.dart';
import 'package:paysense/shared/widgets/app_card.dart';

class FinancialHealthCard extends ConsumerWidget {
  const FinancialHealthCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(financialHealthProvider);

    return AppCard(
      onTap: () => Navigator.of(context).pushNamed(AppRoutes.financialHealth),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Financial Health',
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
            ],
          ),
          const SizedBox(height: 12),
          if (!health.hasSufficientData)
            Text(
              'Add a few transactions to see your Financial Health score.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            )
          else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${health.overallScore}',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6, left: 4),
                  child: Text(
                    '/ 100',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _StatusChip(status: health.status),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _ComponentStat(label: 'Savings', score: health.components.savings),
                _ComponentStat(label: 'Budget', score: health.components.budget),
                _ComponentStat(label: 'Goals', score: health.components.goals),
                _ComponentStat(label: 'Debt', score: health.components.debt),
                _ComponentStat(label: 'Payments', score: health.components.payments),
              ],
            ),
            if (health.insights.isNotEmpty) ...[
              const SizedBox(height: 16),
              _InsightRow(insight: health.insights.first),
            ],
          ],
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final FinancialHealthStatus status;

  @override
  Widget build(BuildContext context) {
    final color = financialHealthStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        financialHealthStatusLabel(status),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}

class _ComponentStat extends StatelessWidget {
  const _ComponentStat({required this.label, required this.score});

  final String label;
  final int score;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            '$score',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightRow extends StatelessWidget {
  const _InsightRow({required this.insight});

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
      padding: const EdgeInsets.all(12),
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
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
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

Color financialHealthStatusColor(FinancialHealthStatus status) {
  switch (status) {
    case FinancialHealthStatus.needsAttention:
      return AppColors.danger;
    case FinancialHealthStatus.gettingStarted:
      return AppColors.warning;
    case FinancialHealthStatus.fair:
      return AppColors.warning;
    case FinancialHealthStatus.good:
      return AppColors.success;
    case FinancialHealthStatus.excellent:
      return AppColors.success;
  }
}
