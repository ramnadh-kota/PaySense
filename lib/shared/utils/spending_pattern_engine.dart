import 'package:intl/intl.dart';

import '../models/decision_memory_record.dart';
import '../models/spending_pattern.dart';
import '../models/transaction.dart';

/// Pure Dart, deterministic engine for analyzing repeated spending patterns
/// and decision habits without judgment.
class SpendingPatternEngine {
  SpendingPatternEngine._();

  static const int defaultLookbackDays = 30;
  static const double smallPurchaseThreshold = 250.0;
  static const int minSmallPurchaseCount = 6;
  static const int minCategoryFrequency = 5;
  static const int minMerchantFrequency = 4;
  static const int maxDashboardPatterns = 3;

  /// Analyzes transactions and decision memory history to detect recurring patterns.
  static List<SpendingPattern> analyze({
    required List<Transaction> transactions,
    List<DecisionMemoryRecord> decisionHistory = const [],
    DateTime? now,
    int lookbackDays = defaultLookbackDays,
  }) {
    final referenceNow = now ?? DateTime.now();
    final currentWindowStart = referenceNow.subtract(Duration(days: lookbackDays));
    final priorWindowStart = currentWindowStart.subtract(Duration(days: lookbackDays));

    // Filter valid expense transactions in current and prior windows
    final currentExpenses = transactions.where((t) {
      return t.transactionType.toLowerCase() == 'expense' &&
          !t.createdAt.isBefore(currentWindowStart) &&
          !t.createdAt.isAfter(referenceNow) &&
          t.amount > 0;
    }).toList();

    final priorExpenses = transactions.where((t) {
      return t.transactionType.toLowerCase() == 'expense' &&
          !t.createdAt.isBefore(priorWindowStart) &&
          t.createdAt.isBefore(currentWindowStart) &&
          t.amount > 0;
    }).toList();

    // Insufficient transaction history
    if (currentExpenses.length < 3) {
      return const [
        SpendingPattern(
          type: SpendingPatternType.insufficientHistory,
          title: 'Building your spending patterns',
          description:
              'Keep tracking your daily expenses to discover your repeated spending habits.',
          priority: 1,
        ),
      ];
    }

    final detected = <SpendingPattern>[];

    // 1. Frequent Category Detection
    final categoryCounts = <String, int>{};
    final categoryTotals = <String, double>{};
    for (final tx in currentExpenses) {
      final cat = _normalizeCategory(tx.categoryId);
      categoryCounts[cat] = (categoryCounts[cat] ?? 0) + 1;
      categoryTotals[cat] = (categoryTotals[cat] ?? 0.0) + tx.amount;
    }

    final totalTxCount = currentExpenses.length;
    for (final entry in categoryCounts.entries) {
      final count = entry.value;
      final category = entry.key;
      final share = count / totalTxCount;
      if (count >= minCategoryFrequency && share >= 0.25) {
        final catDisplay = _formatCategoryName(category);
        detected.add(
          SpendingPattern(
            type: SpendingPatternType.frequentCategory,
            title: '$catDisplay appears frequently',
            description:
                "You've made $count $catDisplay purchases in the last $lookbackDays days.",
            categoryId: category,
            occurrenceCount: count,
            supportingValue: categoryTotals[category],
            period: 'last $lookbackDays days',
            priority: 9,
          ),
        );
      }
    }

    // 2. Repeated Merchant Detection
    final merchantCounts = <String, int>{};
    final merchantTotals = <String, double>{};
    for (final tx in currentExpenses) {
      final merchant = tx.title.trim();
      if (_isValidMerchantName(merchant)) {
        merchantCounts[merchant] = (merchantCounts[merchant] ?? 0) + 1;
        merchantTotals[merchant] = (merchantTotals[merchant] ?? 0.0) + tx.amount;
      }
    }

    for (final entry in merchantCounts.entries) {
      final merchant = entry.key;
      final count = entry.value;
      if (count >= minMerchantFrequency) {
        detected.add(
          SpendingPattern(
            type: SpendingPatternType.repeatedMerchant,
            title: '$merchant visited repeatedly',
            description:
                'You have $count transactions at $merchant in the last $lookbackDays days.',
            merchantName: merchant,
            occurrenceCount: count,
            supportingValue: merchantTotals[merchant],
            period: 'last $lookbackDays days',
            priority: 8,
          ),
        );
      }
    }

    // 3. Category Increase vs Prior Period & 7. Stable Category
    final priorCategoryTotals = <String, double>{};
    final priorCategoryCounts = <String, int>{};
    for (final tx in priorExpenses) {
      final cat = _normalizeCategory(tx.categoryId);
      priorCategoryTotals[cat] = (priorCategoryTotals[cat] ?? 0.0) + tx.amount;
      priorCategoryCounts[cat] = (priorCategoryCounts[cat] ?? 0) + 1;
    }

    for (final entry in categoryTotals.entries) {
      final cat = entry.key;
      final currentTotal = entry.value;
      final priorTotal = priorCategoryTotals[cat] ?? 0.0;
      final catDisplay = _formatCategoryName(cat);

      if (currentTotal >= 1000 && priorTotal >= 500) {
        final changePct = ((currentTotal - priorTotal) / priorTotal) * 100.0;
        if (changePct.isFinite && changePct >= 25.0) {
          detected.add(
            SpendingPattern(
              type: SpendingPatternType.increasingCategory,
              title: '$catDisplay spending is increasing',
              description:
                  '$catDisplay spending is higher than the previous $lookbackDays-day period.',
              categoryId: cat,
              percentageChange: double.parse(changePct.toStringAsFixed(1)),
              supportingValue: currentTotal,
              period: 'vs previous period',
              priority: 8,
            ),
          );
        } else if (changePct.isFinite && changePct.abs() <= 10.0 && (categoryCounts[cat] ?? 0) >= 2) {
          detected.add(
            SpendingPattern(
              type: SpendingPatternType.stableCategory,
              title: 'Consistent $catDisplay spending',
              description:
                  '$catDisplay spending remained steady compared to the previous period.',
              categoryId: cat,
              percentageChange: double.parse(changePct.toStringAsFixed(1)),
              supportingValue: currentTotal,
              period: 'vs previous period',
              priority: 4,
            ),
          );
        }
      }
    }

    // 4. Weekend-Heavy Spending
    final weekendCategorySpend = <String, double>{};
    final weekendCategoryCount = <String, int>{};
    for (final tx in currentExpenses) {
      final isWeekend = tx.createdAt.weekday == DateTime.saturday ||
          tx.createdAt.weekday == DateTime.sunday;
      if (isWeekend) {
        final cat = _normalizeCategory(tx.categoryId);
        weekendCategorySpend[cat] = (weekendCategorySpend[cat] ?? 0.0) + tx.amount;
        weekendCategoryCount[cat] = (weekendCategoryCount[cat] ?? 0) + 1;
      }
    }

    for (final entry in weekendCategorySpend.entries) {
      final cat = entry.key;
      final weekendSpend = entry.value;
      final totalCatSpend = categoryTotals[cat] ?? 0.0;
      final totalCatCount = categoryCounts[cat] ?? 0;

      if (totalCatCount >= 4 && totalCatSpend > 0) {
        final weekendShare = weekendSpend / totalCatSpend;
        if (weekendShare >= 0.60) {
          final catDisplay = _formatCategoryName(cat);
          detected.add(
            SpendingPattern(
              type: SpendingPatternType.weekendHeavy,
              title: 'Weekend-heavy $catDisplay',
              description:
                  'Most of your $catDisplay spending takes place on Saturdays and Sundays.',
              categoryId: cat,
              occurrenceCount: weekendCategoryCount[cat],
              supportingValue: weekendSpend,
              period: 'weekends',
              priority: 6,
            ),
          );
        }
      }
    }

    // 5. Small Purchase Frequency
    final smallPurchases = currentExpenses.where((tx) => tx.amount <= smallPurchaseThreshold).toList();
    if (smallPurchases.length >= minSmallPurchaseCount) {
      final smallTotal = smallPurchases.fold<double>(0.0, (sum, tx) => sum + tx.amount);
      final formattedTotal = NumberFormat.currency(
        symbol: '₹',
        decimalDigits: 0,
        locale: 'en_IN',
      ).format(smallTotal);

      detected.add(
        SpendingPattern(
          type: SpendingPatternType.smallPurchaseFrequency,
          title: 'Small purchases add up',
          description:
              '${smallPurchases.length} small purchases totaled $formattedTotal across the month.',
          occurrenceCount: smallPurchases.length,
          supportingValue: smallTotal,
          period: 'last $lookbackDays days',
          priority: 6,
        ),
      );
    }

    // 6. Repeated Decision Pattern (Decision Memory)
    if (decisionHistory.isNotEmpty) {
      final recentDecisions = decisionHistory.where((r) {
        return !r.timestamp.isBefore(currentWindowStart) &&
            !r.timestamp.isAfter(referenceNow);
      }).toList();

      if (recentDecisions.length >= 3) {
        final cancelledCount = recentDecisions.where((r) => r.wasCancelled).length;
        final proceededCount = recentDecisions.where((r) => r.wasProceeded).length;

        if (cancelledCount >= 2 && cancelledCount >= proceededCount) {
          detected.add(
            SpendingPattern(
              type: SpendingPatternType.repeatedDecisionPattern,
              title: 'Mindful purchase pauses',
              description:
                  "You've chosen to pause on $cancelledCount spending decisions recently.",
              occurrenceCount: cancelledCount,
              period: 'recent decisions',
              priority: 7,
            ),
          );
        } else if (proceededCount >= 3) {
          detected.add(
            SpendingPattern(
              type: SpendingPatternType.repeatedDecisionPattern,
              title: 'Active decision pattern',
              description:
                  "You've proceeded with $proceededCount spending decisions recently.",
              occurrenceCount: proceededCount,
              period: 'recent decisions',
              priority: 7,
            ),
          );
        }
      }
    }

    // Fallback if no specific pattern triggered
    if (detected.isEmpty) {
      return const [
        SpendingPattern(
          type: SpendingPatternType.insufficientHistory,
          title: 'Steady spending habits',
          description:
              'No unusual spending spikes or repeated anomalies detected in the last 30 days.',
          priority: 1,
        ),
      ];
    }

    // Sort by priority (descending), then by occurrence count or supporting value
    detected.sort((a, b) {
      final cmp = b.priority.compareTo(a.priority);
      if (cmp != 0) return cmp;
      final countA = a.occurrenceCount ?? 0;
      final countB = b.occurrenceCount ?? 0;
      return countB.compareTo(countA);
    });

    // Deduplicate by category/type to avoid redundant entries
    final uniquePatterns = <SpendingPattern>[];
    final seenKeys = <String>{};
    for (final pattern in detected) {
      final key = '${pattern.type.name}_${pattern.categoryId ?? ''}_${pattern.merchantName ?? ''}';
      if (!seenKeys.contains(key)) {
        seenKeys.add(key);
        uniquePatterns.add(pattern);
      }
    }

    return uniquePatterns.take(maxDashboardPatterns).toList();
  }

  static String _normalizeCategory(String? categoryId) {
    if (categoryId == null || categoryId.trim().isEmpty) {
      return 'uncategorized';
    }
    return categoryId.trim().toLowerCase();
  }

  static String _formatCategoryName(String categoryId) {
    if (categoryId.isEmpty || categoryId == 'uncategorized') {
      return 'General';
    }
    return categoryId[0].toUpperCase() + categoryId.substring(1);
  }

  static bool _isValidMerchantName(String name) {
    final lower = name.toLowerCase();
    if (lower.isEmpty ||
        lower == 'expense' ||
        lower == 'income' ||
        lower == 'transfer' ||
        lower == 'uncategorized' ||
        lower == 'general') {
      return false;
    }
    return true;
  }
}
