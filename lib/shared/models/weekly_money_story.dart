import 'package:flutter/foundation.dart';

@immutable
class WeeklyMoneyStory {
  const WeeklyMoneyStory({
    required this.spentThisWeek,
    required this.savedThisWeek,
    required this.largestCategory,
    required this.largestCategoryAmount,
    required this.safeToSpendRemaining,
    required this.safeToSpendStatus,
    required this.awarenessStreakDays,
    required this.summaryHeadline,
    required this.summaryNarrative,
    required this.hasSufficientData,
  });

  final double spentThisWeek;
  final double savedThisWeek;
  final String? largestCategory;
  final double largestCategoryAmount;
  final double safeToSpendRemaining;
  final String safeToSpendStatus;
  final int awarenessStreakDays;
  final String summaryHeadline;
  final String summaryNarrative;
  final bool hasSufficientData;

  factory WeeklyMoneyStory.empty({int streakDays = 1}) {
    return WeeklyMoneyStory(
      spentThisWeek: 0,
      savedThisWeek: 0,
      largestCategory: null,
      largestCategoryAmount: 0,
      safeToSpendRemaining: 0,
      safeToSpendStatus: 'Comfortable',
      awarenessStreakDays: streakDays,
      summaryHeadline: 'Weekly Money Snapshot',
      summaryNarrative:
          'Keep tracking for a little longer. PaySense will summarize your weekly money story once transactions are recorded.',
      hasSufficientData: false,
    );
  }
}
