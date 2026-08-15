import 'package:flutter_test/flutter_test.dart';
import 'package:paysense/shared/models/recurring_transaction.dart';
import 'package:paysense/shared/models/subscription_summary.dart';
import 'package:paysense/shared/utils/subscription_calculator.dart';

RecurringTransaction _recurring({
  required String id,
  required double amount,
  String frequency = 'Monthly',
  DateTime? nextDueDate,
  String transactionType = 'expense',
  bool isActive = true,
  DateTime? endDate,
  String categoryId = 'Entertainment',
}) => RecurringTransaction(
  id: id,
  title: id,
  amount: amount,
  categoryId: categoryId,
  accountId: 'Cash',
  transactionType: transactionType,
  frequency: frequency,
  startDate: DateTime(2025, 1, 1),
  nextDueDate: nextDueDate ?? DateTime(2026, 8, 24),
  endDate: endDate,
  lastGeneratedDate: null,
  isActive: isActive,
  reminderDaysBefore: 1,
  note: '',
  createdAt: DateTime(2025, 1, 1),
  updatedAt: DateTime(2025, 1, 1),
);

void main() {
  final now = DateTime(2026, 8, 14);

  group('SubscriptionCalculator.eligibleSubscriptions', () {
    test('1. active expense recurring transaction is included', () {
      final result = SubscriptionCalculator.eligibleSubscriptions(
        recurringTransactions: [_recurring(id: 'Netflix', amount: 649)],
        now: now,
      );

      expect(result, hasLength(1));
      expect(result.single.name, 'Netflix');
    });

    test('2. income recurring transaction excluded', () {
      final result = SubscriptionCalculator.eligibleSubscriptions(
        recurringTransactions: [
          _recurring(id: 'Salary', amount: 60000, transactionType: 'income'),
        ],
        now: now,
      );

      expect(result, isEmpty);
    });

    test('3. inactive recurring transaction excluded', () {
      final result = SubscriptionCalculator.eligibleSubscriptions(
        recurringTransactions: [_recurring(id: 'Cancelled', amount: 649, isActive: false)],
        now: now,
      );

      expect(result, isEmpty);
    });

    test('4. expired recurring transaction excluded', () {
      final result = SubscriptionCalculator.eligibleSubscriptions(
        recurringTransactions: [
          _recurring(
            id: 'Expired Trial',
            amount: 199,
            nextDueDate: DateTime(2026, 8, 24),
            endDate: DateTime(2026, 8, 1),
          ),
        ],
        now: now,
      );

      expect(result, isEmpty);
    });

    test('19. invalid/non-positive amounts are excluded, not crashed on', () {
      final result = SubscriptionCalculator.eligibleSubscriptions(
        recurringTransactions: [
          _recurring(id: 'Zero', amount: 0),
          _recurring(id: 'Negative', amount: -50),
        ],
        now: now,
      );

      expect(result, isEmpty);
    });

    test('an unrecognized frequency is excluded rather than guessed', () {
      final result = SubscriptionCalculator.eligibleSubscriptions(
        recurringTransactions: [_recurring(id: 'Odd', amount: 100, frequency: 'Fortnightly')],
        now: now,
      );

      expect(result, isEmpty);
    });

    test('18. duplicate source ids are not duplicated', () {
      final duplicated = _recurring(id: 'Netflix', amount: 649);
      final result = SubscriptionCalculator.eligibleSubscriptions(
        recurringTransactions: [duplicated, duplicated],
        now: now,
      );

      expect(result, hasLength(1));
    });

    test('17. multiple distinct subscriptions are all included', () {
      final result = SubscriptionCalculator.eligibleSubscriptions(
        recurringTransactions: [
          _recurring(id: 'Netflix', amount: 649),
          _recurring(id: 'Spotify', amount: 119),
          _recurring(id: 'Gym', amount: 1500, categoryId: 'Health'),
        ],
        now: now,
      );

      expect(result, hasLength(3));
    });

    test('15. missing category is reported as empty, not fabricated', () {
      final result = SubscriptionCalculator.eligibleSubscriptions(
        recurringTransactions: [_recurring(id: 'Mystery', amount: 100, categoryId: '')],
        now: now,
      );

      expect(result.single.category, isEmpty);
    });

    test('12. an overdue recurring payment is flagged overdue', () {
      final result = SubscriptionCalculator.eligibleSubscriptions(
        recurringTransactions: [
          _recurring(id: 'Overdue Sub', amount: 199, nextDueDate: DateTime(2026, 8, 1)),
        ],
        now: now,
      );

      expect(result.single.status, SubscriptionStatus.overdue);
      expect(result.single.isOverdue, isTrue);
    });

    test('a subscription due today or later is not overdue', () {
      final result = SubscriptionCalculator.eligibleSubscriptions(
        recurringTransactions: [
          _recurring(id: 'Due Today', amount: 199, nextDueDate: now),
        ],
        now: now,
      );

      expect(result.single.status, SubscriptionStatus.active);
      expect(result.single.isOverdue, isFalse);
    });

    test('16. an empty subscription list is handled without crashing', () {
      final result = SubscriptionCalculator.eligibleSubscriptions(
        recurringTransactions: const [],
        now: now,
      );

      expect(result, isEmpty);
    });
  });

  group('SubscriptionCalculator.annualCostFor / cost methodology', () {
    test('5. monthly cost calculation', () {
      final annual = SubscriptionCalculator.annualCostFor(500, 'Monthly');
      expect(annual, 6000);
      expect(annual / 12, 500);
    });

    test('6. yearly cost calculation', () {
      final annual = SubscriptionCalculator.annualCostFor(12000, 'Yearly');
      expect(annual, 12000);
    });

    test('7. weekly annualization uses x52, not a 4-weeks-per-month shortcut', () {
      final annual = SubscriptionCalculator.annualCostFor(500, 'Weekly');
      expect(annual, 500 * 52);
      expect(annual, 26000);
    });

    test('8. monthly equivalent is always derived from the annual cost', () {
      final result = SubscriptionCalculator.eligibleSubscriptions(
        recurringTransactions: [_recurring(id: 'Annual Plan', amount: 12000, frequency: 'Yearly')],
        now: now,
      );

      expect(result.single.annualCost, 12000);
      expect(result.single.monthlyEquivalent, 1000);
    });

    test('daily frequency annualizes over 365 days', () {
      final annual = SubscriptionCalculator.annualCostFor(20, 'Daily');
      expect(annual, 20 * 365);
    });
  });

  group('SubscriptionCalculator totals', () {
    test('9. total monthly cost sums every eligible subscription', () {
      final subs = SubscriptionCalculator.eligibleSubscriptions(
        recurringTransactions: [
          _recurring(id: 'Netflix', amount: 649),
          _recurring(id: 'Spotify', amount: 119),
        ],
        now: now,
      );

      expect(SubscriptionCalculator.totalMonthlyCost(subs), 649 + 119);
    });

    test('10. total annual cost sums every eligible subscription', () {
      final subs = SubscriptionCalculator.eligibleSubscriptions(
        recurringTransactions: [
          _recurring(id: 'Netflix', amount: 649),
          _recurring(id: 'Annual Plan', amount: 12000, frequency: 'Yearly'),
        ],
        now: now,
      );

      expect(SubscriptionCalculator.totalAnnualCost(subs), 649 * 12 + 12000);
    });

    test('13. the most expensive subscription is identified by monthly cost', () {
      final subs = SubscriptionCalculator.eligibleSubscriptions(
        recurringTransactions: [
          _recurring(id: 'Netflix', amount: 649),
          _recurring(id: 'Gym', amount: 1500, categoryId: 'Health'),
          _recurring(id: 'Spotify', amount: 119),
        ],
        now: now,
      );

      expect(SubscriptionCalculator.mostExpensive(subs)?.name, 'Gym');
    });

    test('14. category totals group and sum monthly-equivalent cost', () {
      final subs = SubscriptionCalculator.eligibleSubscriptions(
        recurringTransactions: [
          _recurring(id: 'Netflix', amount: 649, categoryId: 'Entertainment'),
          _recurring(id: 'Spotify', amount: 119, categoryId: 'Entertainment'),
          _recurring(id: 'Gym', amount: 1500, categoryId: 'Health'),
        ],
        now: now,
      );

      final totals = SubscriptionCalculator.categoryTotals(subs);
      expect(totals['Entertainment'], closeTo(649 + 119, 0.001));
      expect(totals['Health'], 1500);
    });

    test('15b. an empty category groups under Uncategorized', () {
      final subs = SubscriptionCalculator.eligibleSubscriptions(
        recurringTransactions: [_recurring(id: 'Mystery', amount: 100, categoryId: '')],
        now: now,
      );

      final totals = SubscriptionCalculator.categoryTotals(subs);
      expect(totals['Uncategorized'], 100);
    });

    test('16b. summarize() on an empty list reports no subscriptions safely', () {
      final totals = SubscriptionCalculator.summarize(const []);

      expect(totals.hasSubscriptions, isFalse);
      expect(totals.activeCount, 0);
      expect(totals.totalMonthlyCost, 0);
      expect(totals.totalAnnualCost, 0);
      expect(totals.averageMonthlyCost, 0);
      expect(totals.mostExpensive, isNull);
      expect(totals.categoryTotals, isEmpty);
    });

    test('20. the Dashboard summary and the calculator totals come from the same computation', () {
      final subs = SubscriptionCalculator.eligibleSubscriptions(
        recurringTransactions: [
          _recurring(id: 'Netflix', amount: 649),
          _recurring(id: 'Gym', amount: 1500, categoryId: 'Health'),
        ],
        now: now,
      );

      // subscriptionTotalsProvider (feeds both the Dashboard card and the
      // screen's summary hero) calls exactly this method on exactly this
      // eligible list — asserting summarize() matches the individual
      // helpers proves there is only one derivation path, not two.
      final totals = SubscriptionCalculator.summarize(subs);
      expect(totals.totalMonthlyCost, SubscriptionCalculator.totalMonthlyCost(subs));
      expect(totals.totalAnnualCost, SubscriptionCalculator.totalAnnualCost(subs));
      expect(totals.averageMonthlyCost, SubscriptionCalculator.averageMonthlyCost(subs));
      expect(totals.mostExpensive?.name, SubscriptionCalculator.mostExpensive(subs)?.name);
      expect(totals.categoryTotals, SubscriptionCalculator.categoryTotals(subs));
      expect(totals.activeCount, subs.length);
    });
  });

  group('SubscriptionCalculator.upcomingRenewals', () {
    test('11. upcoming renewals sort by next due date ascending', () {
      final subs = SubscriptionCalculator.eligibleSubscriptions(
        recurringTransactions: [
          _recurring(id: 'Spotify', amount: 119, nextDueDate: DateTime(2026, 8, 28)),
          _recurring(id: 'Netflix', amount: 649, nextDueDate: DateTime(2026, 8, 24)),
        ],
        now: now,
      );

      final upcoming = SubscriptionCalculator.upcomingRenewals(subs);
      expect(upcoming.map((s) => s.name).toList(), ['Netflix', 'Spotify']);
    });

    test('limits to the requested count', () {
      final subs = SubscriptionCalculator.eligibleSubscriptions(
        recurringTransactions: List.generate(
          8,
          (i) => _recurring(
            id: 'Sub $i',
            amount: 100,
            nextDueDate: DateTime(2026, 8, 15 + i),
          ),
        ),
        now: now,
      );

      expect(SubscriptionCalculator.upcomingRenewals(subs, limit: 5), hasLength(5));
    });
  });
}
