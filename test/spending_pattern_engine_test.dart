import 'package:flutter_test/flutter_test.dart';
import 'package:paysense/shared/models/decision_memory_record.dart';
import 'package:paysense/shared/models/spending_pattern.dart';
import 'package:paysense/shared/models/transaction.dart';
import 'package:paysense/shared/utils/spending_decision_calculator.dart';
import 'package:paysense/shared/utils/spending_pattern_engine.dart';

final _now = DateTime(2026, 8, 30, 12, 0);

Transaction _tx({
  required String id,
  required double amount,
  required String categoryId,
  required DateTime createdAt,
  String? merchantName,
  String type = 'expense',
}) {
  return Transaction(
    id: id,
    title: merchantName ?? categoryId,
    amount: amount,
    categoryId: categoryId,
    accountId: 'w1',
    transactionType: type,
    paymentMethod: 'UPI',
    note: '',
    createdAt: createdAt,
  );
}

void main() {
  group('SpendingPatternEngine — Phase 6E Step 7 Unit Tests', () {
    test('1. Empty transaction list returns insufficientHistory pattern', () {
      final patterns = SpendingPatternEngine.analyze(
        transactions: const [],
        now: _now,
      );

      expect(patterns.length, 1);
      expect(patterns.first.type, SpendingPatternType.insufficientHistory);
      expect(patterns.first.title, contains('Building your spending patterns'));
    });

    test('2. Insufficient history (< 3 transactions) returns insufficientHistory', () {
      final transactions = [
        _tx(id: 't1', amount: 500, categoryId: 'dining', createdAt: _now.subtract(const Duration(days: 2))),
        _tx(id: 't2', amount: 300, categoryId: 'groceries', createdAt: _now.subtract(const Duration(days: 1))),
      ];

      final patterns = SpendingPatternEngine.analyze(
        transactions: transactions,
        now: _now,
      );

      expect(patterns.length, 1);
      expect(patterns.first.type, SpendingPatternType.insufficientHistory);
    });

    test('3. Frequent Category detected when >= 5 transactions and >= 25% share', () {
      final transactions = <Transaction>[];
      for (var i = 1; i <= 6; i++) {
        transactions.add(
          _tx(
            id: 'd-$i',
            amount: 400,
            categoryId: 'dining',
            createdAt: _now.subtract(Duration(days: i)),
          ),
        );
      }
      transactions.add(
        _tx(id: 'g-1', amount: 800, categoryId: 'groceries', createdAt: _now.subtract(const Duration(days: 5))),
      );

      final patterns = SpendingPatternEngine.analyze(
        transactions: transactions,
        now: _now,
      );

      final frequent = patterns.where((p) => p.type == SpendingPatternType.frequentCategory).toList();
      expect(frequent, isNotEmpty);
      expect(frequent.first.categoryId, 'dining');
      expect(frequent.first.occurrenceCount, 6);
      expect(frequent.first.title, contains('Dining appears frequently'));
    });

    test('4. Repeated Merchant detected when >= 4 transactions at same merchant', () {
      final transactions = <Transaction>[
        _tx(id: 'm1', amount: 200, categoryId: 'coffee', merchantName: 'Starbucks', createdAt: _now.subtract(const Duration(days: 2))),
        _tx(id: 'm2', amount: 250, categoryId: 'coffee', merchantName: 'Starbucks', createdAt: _now.subtract(const Duration(days: 4))),
        _tx(id: 'm3', amount: 220, categoryId: 'coffee', merchantName: 'Starbucks', createdAt: _now.subtract(const Duration(days: 7))),
        _tx(id: 'm4', amount: 300, categoryId: 'coffee', merchantName: 'Starbucks', createdAt: _now.subtract(const Duration(days: 10))),
        _tx(id: 'other', amount: 1500, categoryId: 'groceries', merchantName: 'Supermarket', createdAt: _now.subtract(const Duration(days: 12))),
      ];

      final patterns = SpendingPatternEngine.analyze(
        transactions: transactions,
        now: _now,
      );

      final merchantPattern = patterns.where((p) => p.type == SpendingPatternType.repeatedMerchant).toList();
      expect(merchantPattern, isNotEmpty);
      expect(merchantPattern.first.merchantName, 'Starbucks');
      expect(merchantPattern.first.occurrenceCount, 4);
    });

    test('5. Increasing Category detected when spend increases by >= 25% vs prior 30 days', () {
      final transactions = <Transaction>[
        // Prior period (31-60 days ago): ₹1,000 travel
        _tx(id: 'p1', amount: 1000, categoryId: 'travel', createdAt: _now.subtract(const Duration(days: 45))),
        // Current period (last 30 days): ₹2,500 travel (+150%)
        _tx(id: 'c1', amount: 1200, categoryId: 'travel', createdAt: _now.subtract(const Duration(days: 5))),
        _tx(id: 'c2', amount: 1300, categoryId: 'travel', createdAt: _now.subtract(const Duration(days: 12))),
        _tx(id: 'c3', amount: 400, categoryId: 'food', createdAt: _now.subtract(const Duration(days: 15))),
      ];

      final patterns = SpendingPatternEngine.analyze(
        transactions: transactions,
        now: _now,
      );

      final increasing = patterns.where((p) => p.type == SpendingPatternType.increasingCategory).toList();
      expect(increasing, isNotEmpty);
      expect(increasing.first.categoryId, 'travel');
      expect(increasing.first.percentageChange, 150.0);
    });

    test('6. Weekend-heavy category detected when >= 60% of spend occurs on weekends', () {
      // 2026-08-30 is a Sunday (weekend), 2026-08-29 is a Saturday (weekend)
      final transactions = <Transaction>[
        _tx(id: 'w1', amount: 1500, categoryId: 'entertainment', createdAt: DateTime(2026, 8, 29, 20, 0)), // Sat
        _tx(id: 'w2', amount: 1200, categoryId: 'entertainment', createdAt: DateTime(2026, 8, 30, 10, 0)), // Sun (before 12:00)
        _tx(id: 'w3', amount: 1000, categoryId: 'entertainment', createdAt: DateTime(2026, 8, 22, 19, 0)), // Sat
        _tx(id: 'w4', amount: 300, categoryId: 'entertainment', createdAt: DateTime(2026, 8, 25, 12, 0)), // Tue
      ];

      final patterns = SpendingPatternEngine.analyze(
        transactions: transactions,
        now: _now,
      );

      final weekend = patterns.where((p) => p.type == SpendingPatternType.weekendHeavy).toList();
      expect(weekend, isNotEmpty);
      expect(weekend.first.categoryId, 'entertainment');
      expect(weekend.first.title, contains('Weekend-heavy Entertainment'));
    });

    test('7. Small Purchase Frequency detected when >= 6 purchases <= 250', () {
      final transactions = <Transaction>[];
      for (var i = 1; i <= 7; i++) {
        transactions.add(
          _tx(
            id: 'sm-$i',
            amount: 150,
            categoryId: 'snacks',
            createdAt: _now.subtract(Duration(days: i * 2)),
          ),
        );
      }

      final patterns = SpendingPatternEngine.analyze(
        transactions: transactions,
        now: _now,
      );

      final small = patterns.where((p) => p.type == SpendingPatternType.smallPurchaseFrequency).toList();
      expect(small, isNotEmpty);
      expect(small.first.occurrenceCount, 7);
      expect(small.first.title, 'Small purchases add up');
    });

    test('8. Repeated Decision Memory: mindful purchase pauses detected', () {
      final transactions = <Transaction>[
        _tx(id: 't1', amount: 500, categoryId: 'general', createdAt: _now.subtract(const Duration(days: 1))),
        _tx(id: 't2', amount: 500, categoryId: 'general', createdAt: _now.subtract(const Duration(days: 2))),
        _tx(id: 't3', amount: 500, categoryId: 'general', createdAt: _now.subtract(const Duration(days: 3))),
      ];

      final history = [
        DecisionMemoryRecord(
          id: 'dm1',
          timestamp: _now.subtract(const Duration(days: 5)),
          categoryId: 'shopping',
          amount: 3000,
          recommendationTier: SpendingRecommendationTier.thinkAgain,
          userAction: DecisionUserAction.cancelled,
          verdictLine: 'Think again',
        ),
        DecisionMemoryRecord(
          id: 'dm2',
          timestamp: _now.subtract(const Duration(days: 3)),
          categoryId: 'shopping',
          amount: 2500,
          recommendationTier: SpendingRecommendationTier.thinkAgain,
          userAction: DecisionUserAction.cancelled,
          verdictLine: 'Think again',
        ),
        DecisionMemoryRecord(
          id: 'dm3',
          timestamp: _now.subtract(const Duration(days: 1)),
          categoryId: 'dining',
          amount: 1500,
          recommendationTier: SpendingRecommendationTier.spend,
          userAction: DecisionUserAction.proceeded,
          verdictLine: 'OK',
        ),
      ];

      final patterns = SpendingPatternEngine.analyze(
        transactions: transactions,
        decisionHistory: history,
        now: _now,
      );

      final decisionPattern = patterns.where((p) => p.type == SpendingPatternType.repeatedDecisionPattern).toList();
      expect(decisionPattern, isNotEmpty);
      expect(decisionPattern.first.title, 'Mindful purchase pauses');
      expect(decisionPattern.first.occurrenceCount, 2);
    });

    test('9. Limits output to maximum 3 patterns in prioritized order without NaNs', () {
      final transactions = <Transaction>[];
      // Generate multiple candidate patterns
      for (var i = 1; i <= 6; i++) {
        transactions.add(_tx(id: 'd-$i', amount: 400, categoryId: 'dining', createdAt: _now.subtract(Duration(days: i))));
        transactions.add(_tx(id: 'm-$i', amount: 150, categoryId: 'coffee', merchantName: 'Cafe', createdAt: _now.subtract(Duration(days: i))));
      }

      final patterns = SpendingPatternEngine.analyze(
        transactions: transactions,
        now: _now,
      );

      expect(patterns.length, inInclusiveRange(1, 3));
      for (final p in patterns) {
        if (p.percentageChange != null) {
          expect(p.percentageChange!.isNaN, isFalse);
          expect(p.percentageChange!.isInfinite, isFalse);
        }
        if (p.supportingValue != null) {
          expect(p.supportingValue!.isNaN, isFalse);
          expect(p.supportingValue!.isInfinite, isFalse);
        }
      }
    });

    test('10. Income transactions are ignored in spending patterns', () {
      final transactions = [
        _tx(id: 'inc1', amount: 50000, categoryId: 'salary', type: 'income', createdAt: _now.subtract(const Duration(days: 1))),
        _tx(id: 'inc2', amount: 50000, categoryId: 'salary', type: 'income', createdAt: _now.subtract(const Duration(days: 15))),
      ];

      final patterns = SpendingPatternEngine.analyze(
        transactions: transactions,
        now: _now,
      );

      expect(patterns.length, 1);
      expect(patterns.first.type, SpendingPatternType.insufficientHistory);
    });
  });
}
