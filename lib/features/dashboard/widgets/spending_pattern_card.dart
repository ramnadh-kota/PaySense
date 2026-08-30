import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/models/spending_pattern.dart';
import '../../../shared/providers/spending_patterns_provider.dart';
import '../../../shared/widgets/app_card.dart';

/// Phase 6E Step 7 — Spending Pattern Card
///
/// Displays respectful, non-judgmental spending pattern intelligence on the dashboard.
class SpendingPatternCard extends ConsumerWidget {
  const SpendingPatternCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patternsAsync = ref.watch(spendingPatternsWithMemoryProvider);
    final theme = Theme.of(context);

    return patternsAsync.when(
      data: (patterns) => _buildCard(context, theme, patterns),
      loading: () {
        // Fallback to synchronous provider while async memory history loads
        final syncPatterns = ref.watch(spendingPatternsProvider);
        return _buildCard(context, theme, syncPatterns);
      },
      error: (_, _) {
        final syncPatterns = ref.watch(spendingPatternsProvider);
        return _buildCard(context, theme, syncPatterns);
      },
    );
  }

  Widget _buildCard(
    BuildContext context,
    ThemeData theme,
    List<SpendingPattern> patterns,
  ) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.auto_graph_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Spending Patterns',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Notice where your money is repeatedly going.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (patterns.isEmpty)
            _buildEmptyState(context, theme)
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: patterns.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final pattern = patterns[index];
                return _buildPatternItem(context, theme, pattern);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 20,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Keep logging transactions to discover your spending patterns.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatternItem(
    BuildContext context,
    ThemeData theme,
    SpendingPattern pattern,
  ) {
    final iconData = _iconForType(pattern.type);
    final accentColor = _colorForType(pattern.type);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.divider.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              iconData,
              size: 16,
              color: accentColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        pattern.title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (pattern.percentageChange != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: (pattern.percentageChange! > 0
                                  ? AppColors.warning
                                  : AppColors.success)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${pattern.percentageChange! > 0 ? '+' : ''}${pattern.percentageChange!.toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: pattern.percentageChange! > 0
                                ? AppColors.warning
                                : AppColors.success,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  pattern.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForType(SpendingPatternType type) {
    switch (type) {
      case SpendingPatternType.frequentCategory:
        return Icons.repeat_rounded;
      case SpendingPatternType.repeatedMerchant:
        return Icons.storefront_rounded;
      case SpendingPatternType.increasingCategory:
        return Icons.trending_up_rounded;
      case SpendingPatternType.weekendHeavy:
        return Icons.weekend_rounded;
      case SpendingPatternType.smallPurchaseFrequency:
        return Icons.toll_rounded;
      case SpendingPatternType.repeatedDecisionPattern:
        return Icons.psychology_rounded;
      case SpendingPatternType.stableCategory:
        return Icons.check_circle_outline_rounded;
      case SpendingPatternType.insufficientHistory:
        return Icons.explore_outlined;
    }
  }

  Color _colorForType(SpendingPatternType type) {
    switch (type) {
      case SpendingPatternType.frequentCategory:
        return AppColors.primary;
      case SpendingPatternType.repeatedMerchant:
        return Colors.indigo;
      case SpendingPatternType.increasingCategory:
        return AppColors.warning;
      case SpendingPatternType.weekendHeavy:
        return Colors.deepPurple;
      case SpendingPatternType.smallPurchaseFrequency:
        return Colors.teal;
      case SpendingPatternType.repeatedDecisionPattern:
        return AppColors.primary;
      case SpendingPatternType.stableCategory:
        return AppColors.success;
      case SpendingPatternType.insufficientHistory:
        return AppColors.textSecondary;
    }
  }
}
