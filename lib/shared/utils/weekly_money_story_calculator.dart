import '../models/transaction.dart';
import '../models/weekly_money_story.dart';
import '../providers/daily_check_in_provider.dart';
import 'safe_to_spend_calculator.dart';

class WeeklyMoneyStoryCalculator {
  WeeklyMoneyStoryCalculator._();

  static WeeklyMoneyStory calculate({
    required List<Transaction> transactions,
    required SafeToSpendResult safeToSpend,
    required DailyCheckInState dailyCheckInState,
    required DateTime now,
  }) {
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    final weekTxns = transactions.where((t) {
      final dt = t.createdAt;
      return (dt.isAfter(sevenDaysAgo) || dt.isAtSameMomentAs(sevenDaysAgo)) &&
          (dt.isBefore(now) || dt.isAtSameMomentAs(now));
    }).toList();

    if (weekTxns.isEmpty) {
      return WeeklyMoneyStory.empty(streakDays: dailyCheckInState.streakDays);
    }

    double spentThisWeek = 0;
    double incomeThisWeek = 0;
    final categoryTotals = <String, double>{};

    for (final t in weekTxns) {
      final type = t.transactionType.toLowerCase();
      if (type == 'expense') {
        spentThisWeek += t.amount;
        final cat = t.categoryId.isNotEmpty ? t.categoryId : 'General';
        categoryTotals[cat] = (categoryTotals[cat] ?? 0) + t.amount;
      } else if (type == 'income') {
        incomeThisWeek += t.amount;
      }
    }

    final savedThisWeek = (incomeThisWeek - spentThisWeek) > 0 ? (incomeThisWeek - spentThisWeek) : 0.0;

    String? largestCategory;
    double largestCategoryAmount = 0;
    categoryTotals.forEach((cat, amt) {
      if (amt > largestCategoryAmount) {
        largestCategoryAmount = amt;
        largestCategory = cat;
      }
    });

    final isCaution = safeToSpend.availableMoney > 0 &&
        (safeToSpend.upcomingCommitments / safeToSpend.availableMoney >= 0.7);

    final safeStatus = safeToSpend.isShortfall
        ? 'Tight'
        : (isCaution ? 'Watchful' : 'Comfortable');

    final headline = 'Weekly Money Snapshot: Spending $safeStatus';

    final String narrative;
    if (spentThisWeek == 0) {
      narrative =
          'You recorded ₹${incomeThisWeek.toStringAsFixed(0)} in income this week with 0 expense transactions. Your awareness streak is ${dailyCheckInState.streakDays} day(s).';
    } else {
      final catPhrase = largestCategory != null
          ? '$largestCategory is your largest category (₹${largestCategoryAmount.toStringAsFixed(0)}).'
          : '';
      narrative =
          "You're spending $safeStatus this week at ₹${spentThisWeek.toStringAsFixed(0)} across ${weekTxns.length} transaction(s). $catPhrase Overall spending remains within your $safeStatus safe-to-spend range with a ${dailyCheckInState.streakDays}-day awareness streak.";
    }

    return WeeklyMoneyStory(
      spentThisWeek: spentThisWeek,
      savedThisWeek: savedThisWeek,
      largestCategory: largestCategory,
      largestCategoryAmount: largestCategoryAmount,
      safeToSpendRemaining: safeToSpend.safeToSpend,
      safeToSpendStatus: safeStatus,
      awarenessStreakDays: dailyCheckInState.streakDays,
      summaryHeadline: headline,
      summaryNarrative: narrative,
      hasSufficientData: true,
    );
  }
}
