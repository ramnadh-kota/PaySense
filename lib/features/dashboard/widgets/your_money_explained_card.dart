import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/models/weekly_money_story.dart';
import '../../../shared/providers/financial_insight_provider.dart';
import '../../../shared/repositories/app_settings_repository.dart';
import '../../../shared/utils/financial_insight_engine.dart';
import '../../../shared/widgets/app_card.dart';

class YourMoneyExplainedCard extends ConsumerStatefulWidget {
  const YourMoneyExplainedCard({super.key});

  @override
  ConsumerState<YourMoneyExplainedCard> createState() => _YourMoneyExplainedCardState();
}

class _YourMoneyExplainedCardState extends ConsumerState<YourMoneyExplainedCard> {
  int _selectedSegment = 0; // 0: Insights, 1: Weekly Story

  @override
  Widget build(BuildContext context) {
    final insightResult = ref.watch(financialInsightsProvider);
    final weeklyStory = ref.watch(weeklyMoneyStoryProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
                  Icons.psychology_alt_outlined,
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
                      'Your Money, Explained',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Personal Money Intelligence',
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
          Row(
            children: [
              ChoiceChip(
                label: const Text('Insights'),
                selected: _selectedSegment == 0,
                onSelected: (selected) {
                  if (selected) setState(() => _selectedSegment = 0);
                },
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Weekly Story'),
                selected: _selectedSegment == 1,
                onSelected: (selected) {
                  if (selected) setState(() => _selectedSegment = 1);
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_selectedSegment == 0)
            _buildInsightsTab(context, insightResult, isDark)
          else
            _buildWeeklyStoryTab(context, weeklyStory, isDark),
        ],
      ),
    );
  }

  Widget _buildInsightsTab(
    BuildContext context,
    FinancialInsightResult insightResult,
    bool isDark,
  ) {
    if (insightResult.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(Icons.check_circle_outline, color: AppColors.success, size: 28),
            const SizedBox(height: 8),
            Text(
              'All Clear & Steady',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'No critical risks or pressure detected. PaySense will update insights as new spending arrives.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: insightResult.insights.map((insight) {
        return _buildInsightCard(context, insight, isDark);
      }).toList(),
    );
  }

  Widget _buildInsightCard(
    BuildContext context,
    FinancialInsight insight,
    bool isDark,
  ) {
    final theme = Theme.of(context);
    final badgeColor = _priorityColor(insight.priority);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: badgeColor.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _insightLabel(insight.type).toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: badgeColor,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () async {
                  await AppSettingsRepository.instance.dismissInsight(insight.id);
                  ref.invalidate(financialInsightsProvider);
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            insight.title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            insight.explanation,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          if (insight.actionRoute != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () {
                  Navigator.pushNamed(context, insight.actionRoute!);
                },
                child: Text(insight.recommendedAction),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWeeklyStoryTab(
    BuildContext context,
    WeeklyMoneyStory weeklyStory,
    bool isDark,
  ) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                weeklyStory.summaryHeadline,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '🔥 ${weeklyStory.awarenessStreakDays} d',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            weeklyStory.summaryNarrative,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          if (weeklyStory.hasSufficientData) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _storyMetric('Spent', '₹${weeklyStory.spentThisWeek.toStringAsFixed(0)}', isDark),
                _storyMetric('Saved', '₹${weeklyStory.savedThisWeek.toStringAsFixed(0)}', isDark),
                _storyMetric(
                  'Top Cat.',
                  weeklyStory.largestCategory ?? 'None',
                  isDark,
                ),
                _storyMetric('Status', weeklyStory.safeToSpendStatus, isDark),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _storyMetric(String label, String value, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Color _priorityColor(InsightPriority priority) {
    switch (priority) {
      case InsightPriority.critical:
        return AppColors.danger;
      case InsightPriority.high:
        return AppColors.warning;
      case InsightPriority.medium:
        return AppColors.primary;
      case InsightPriority.low:
        return AppColors.secondary;
      case InsightPriority.positive:
        return AppColors.success;
    }
  }

  String _insightLabel(InsightType type) {
    switch (type) {
      case InsightType.spendingTrend:
        return 'Spending Trend';
      case InsightType.categoryPressure:
        return 'Category Pressure';
      case InsightType.frequencyAlert:
        return 'Frequency Alert';
      case InsightType.subscriptionAwareness:
      case InsightType.subscriptionIncrease:
        return 'Subscription';
      case InsightType.goalImpact:
      case InsightType.goalFallingBehind:
        return 'Goal Impact';
      case InsightType.emiPressure:
        return 'EMI Pressure';
      case InsightType.safeToSpendSignal:
      case InsightType.upcomingCommitmentPressure:
        return 'Safe-to-Spend';
      case InsightType.behaviorImprovement:
      case InsightType.positiveImprovement:
        return 'Progress';
      case InsightType.checkInCorrelation:
        return 'Check-In';
      case InsightType.insufficientData:
        return 'Guidance';
      default:
        return 'Insight';
    }
  }
}
