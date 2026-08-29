import 'package:flutter_test/flutter_test.dart';
import 'package:paysense/shared/models/decision_memory_record.dart';
import 'package:paysense/shared/utils/affordability_calculator.dart';
import 'package:paysense/shared/utils/allowance_calculator.dart';
import 'package:paysense/shared/utils/spending_decision_calculator.dart';

void main() {
  final now = DateTime(2026, 8, 30, 10, 30);

  group('DecisionMemoryRecord — Phase 6E Unit Tests', () {
    test('1. Record creation with full fields', () {
      final record = DecisionMemoryRecord(
        id: 'dm-1',
        timestamp: now,
        categoryId: 'dining',
        amount: 2500,
        recommendationTier: SpendingRecommendationTier.thinkAgain,
        userAction: DecisionUserAction.cancelled,
        verdictLine: 'Approaching monthly limit for Dining.',
        allowanceState: AllowanceState.watchful,
        affordabilityStatus: AffordabilityStatus.possible,
        itemDescription: 'Team lunch',
      );

      expect(record.id, 'dm-1');
      expect(record.timestamp, now);
      expect(record.categoryId, 'dining');
      expect(record.amount, 2500.0);
      expect(record.recommendationTier, SpendingRecommendationTier.thinkAgain);
      expect(record.userAction, DecisionUserAction.cancelled);
      expect(record.wasCancelled, isTrue);
      expect(record.wasProceeded, isFalse);
      expect(record.verdictLine, 'Approaching monthly limit for Dining.');
      expect(record.allowanceState, AllowanceState.watchful);
      expect(record.affordabilityStatus, AffordabilityStatus.possible);
      expect(record.itemDescription, 'Team lunch');
    });

    test('2. toMap() produces expected map structure', () {
      final record = DecisionMemoryRecord(
        id: 'dm-2',
        timestamp: now,
        categoryId: 'shopping',
        amount: 5000,
        recommendationTier: SpendingRecommendationTier.avoid,
        userAction: DecisionUserAction.proceeded,
        verdictLine: 'Category limit reached for Shopping.',
        allowanceState: AllowanceState.overAllowance,
        affordabilityStatus: AffordabilityStatus.risky,
      );

      final map = record.toMap();

      expect(map['id'], 'dm-2');
      expect(map['timestamp'], now.toIso8601String());
      expect(map['categoryId'], 'shopping');
      expect(map['amount'], 5000.0);
      expect(map['recommendationTier'], 'avoid');
      expect(map['userAction'], 'proceeded');
      expect(map['verdictLine'], 'Category limit reached for Shopping.');
      expect(map['allowanceState'], 'overAllowance');
      expect(map['affordabilityStatus'], 'risky');
      expect(map.containsKey('itemDescription'), isFalse);
    });

    test('3. fromMap() parses map correctly', () {
      final map = {
        'id': 'dm-3',
        'timestamp': now.toIso8601String(),
        'categoryId': 'groceries',
        'amount': 1200.0,
        'recommendationTier': 'spend',
        'userAction': 'proceeded',
        'verdictLine': 'Purchase looks comfortable within your current spending limits.',
        'allowanceState': 'comfortable',
        'affordabilityStatus': 'comfortable',
        'itemDescription': 'Weekly groceries',
      };

      final record = DecisionMemoryRecord.fromMap(map);

      expect(record.id, 'dm-3');
      expect(record.timestamp, now);
      expect(record.categoryId, 'groceries');
      expect(record.amount, 1200.0);
      expect(record.recommendationTier, SpendingRecommendationTier.spend);
      expect(record.userAction, DecisionUserAction.proceeded);
      expect(record.wasProceeded, isTrue);
      expect(record.allowanceState, AllowanceState.comfortable);
      expect(record.affordabilityStatus, AffordabilityStatus.comfortable);
      expect(record.itemDescription, 'Weekly groceries');
    });

    test('4. Round-trip serialization preserves equality', () {
      final original = DecisionMemoryRecord(
        id: 'dm-4',
        timestamp: now,
        categoryId: 'entertainment',
        amount: 800,
        recommendationTier: SpendingRecommendationTier.spend,
        userAction: DecisionUserAction.cancelled,
        verdictLine: 'Purchase looks comfortable.',
        allowanceState: AllowanceState.comfortable,
        affordabilityStatus: AffordabilityStatus.comfortable,
        itemDescription: 'Movie ticket',
      );

      final map = original.toMap();
      final restored = DecisionMemoryRecord.fromMap(map);

      expect(restored, equals(original));
      expect(restored.hashCode, equals(original.hashCode));
    });

    test('5. proceeded action vs cancelled action', () {
      final proceeded = DecisionMemoryRecord(
        id: 'p1',
        timestamp: now,
        categoryId: 'travel',
        amount: 300,
        recommendationTier: SpendingRecommendationTier.spend,
        userAction: DecisionUserAction.proceeded,
        verdictLine: 'All good',
      );

      final cancelled = DecisionMemoryRecord(
        id: 'c1',
        timestamp: now,
        categoryId: 'travel',
        amount: 300,
        recommendationTier: SpendingRecommendationTier.spend,
        userAction: DecisionUserAction.cancelled,
        verdictLine: 'All good',
      );

      expect(proceeded.wasProceeded, isTrue);
      expect(proceeded.wasCancelled, isFalse);
      expect(cancelled.wasCancelled, isTrue);
      expect(cancelled.wasProceeded, isFalse);
    });

    test('6. Recommendation tier serialization handles all tiers and fallbacks', () {
      for (final tier in SpendingRecommendationTier.values) {
        final record = DecisionMemoryRecord(
          id: 'tier-${tier.name}',
          timestamp: now,
          categoryId: 'test',
          amount: 100,
          recommendationTier: tier,
          userAction: DecisionUserAction.proceeded,
          verdictLine: 'Test',
        );

        final restored = DecisionMemoryRecord.fromMap(record.toMap());
        expect(restored.recommendationTier, tier);
      }

      // Fallback on unknown string
      final fallbackRecord = DecisionMemoryRecord.fromMap({
        'id': 'unknown',
        'recommendationTier': 'non_existent_tier',
      });
      expect(fallbackRecord.recommendationTier, SpendingRecommendationTier.spend);
    });

    test('7. Nullable fields handle missing/null keys gracefully', () {
      final record = DecisionMemoryRecord.fromMap({
        'id': 'min-1',
        'amount': 200,
      });

      expect(record.id, 'min-1');
      expect(record.amount, 200.0);
      expect(record.categoryId, 'uncategorized');
      expect(record.allowanceState, isNull);
      expect(record.affordabilityStatus, isNull);
      expect(record.itemDescription, isNull);
      expect(record.userAction, DecisionUserAction.cancelled);
    });
  });
}
