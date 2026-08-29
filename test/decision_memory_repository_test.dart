import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:paysense/shared/models/decision_memory_record.dart';
import 'package:paysense/shared/repositories/decision_memory_repository.dart';
import 'package:paysense/shared/utils/affordability_calculator.dart';
import 'package:paysense/shared/utils/allowance_calculator.dart';
import 'package:paysense/shared/utils/spending_decision_calculator.dart';

void main() {
  late Directory tempDir;
  late DecisionMemoryRepository repository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('decision_memory_test_');
    Hive.init(tempDir.path);
    repository = DecisionMemoryRepository.instance;
    await repository.clearAll();
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  final t1 = DateTime(2026, 8, 30, 9, 0);
  final t2 = DateTime(2026, 8, 30, 10, 0);
  final t3 = DateTime(2026, 8, 30, 11, 0);

  group('DecisionMemoryRepository — Phase 6E Unit Tests', () {
    test('1. Empty repository returns empty list safely', () async {
      final all = await repository.getAll();
      expect(all, isEmpty);

      final recent = await repository.getRecentDecisions();
      expect(recent, isEmpty);

      final byCategory = await repository.getByCategory('dining');
      expect(byCategory, isEmpty);

      final similar = await repository.getSimilarDecisions(categoryId: 'dining', amount: 500);
      expect(similar, isEmpty);
    });

    test('2. Saves and retrieves records sorted by timestamp (newest first)', () async {
      final r1 = DecisionMemoryRecord(
        id: 'rec-1',
        timestamp: t1,
        categoryId: 'dining',
        amount: 500,
        recommendationTier: SpendingRecommendationTier.spend,
        userAction: DecisionUserAction.proceeded,
        verdictLine: 'Looks comfortable.',
      );

      final r2 = DecisionMemoryRecord(
        id: 'rec-2',
        timestamp: t3,
        categoryId: 'shopping',
        amount: 2000,
        recommendationTier: SpendingRecommendationTier.thinkAgain,
        userAction: DecisionUserAction.cancelled,
        verdictLine: 'Approaching limit.',
      );

      final r3 = DecisionMemoryRecord(
        id: 'rec-3',
        timestamp: t2,
        categoryId: 'dining',
        amount: 800,
        recommendationTier: SpendingRecommendationTier.spend,
        userAction: DecisionUserAction.proceeded,
        verdictLine: 'Looks comfortable.',
      );

      await repository.recordDecision(r1);
      await repository.recordDecision(r2);
      await repository.recordDecision(r3);

      final all = await repository.getAll();
      expect(all.length, 3);
      // Newest first: r2 (t3), r3 (t2), r1 (t1)
      expect(all[0].id, 'rec-2');
      expect(all[1].id, 'rec-3');
      expect(all[2].id, 'rec-1');
    });

    test('3. Limits recent decisions accurately', () async {
      for (var i = 1; i <= 10; i++) {
        await repository.recordDecision(
          DecisionMemoryRecord(
            id: 'r-$i',
            timestamp: t1.add(Duration(minutes: i)),
            categoryId: 'general',
            amount: 100.0 * i,
            recommendationTier: SpendingRecommendationTier.spend,
            userAction: DecisionUserAction.proceeded,
            verdictLine: 'OK',
          ),
        );
      }

      final recent = await repository.getRecentDecisions(limit: 4);
      expect(recent.length, 4);
      expect(recent[0].id, 'r-10');
      expect(recent[1].id, 'r-9');
      expect(recent[2].id, 'r-8');
      expect(recent[3].id, 'r-7');
    });

    test('4. Category filtering is case-insensitive and respects limit', () async {
      await repository.recordDecision(
        DecisionMemoryRecord(
          id: 'c-1',
          timestamp: t1,
          categoryId: 'Dining',
          amount: 500,
          recommendationTier: SpendingRecommendationTier.spend,
          userAction: DecisionUserAction.proceeded,
          verdictLine: 'OK',
        ),
      );
      await repository.recordDecision(
        DecisionMemoryRecord(
          id: 'c-2',
          timestamp: t2,
          categoryId: 'dining',
          amount: 600,
          recommendationTier: SpendingRecommendationTier.spend,
          userAction: DecisionUserAction.proceeded,
          verdictLine: 'OK',
        ),
      );
      await repository.recordDecision(
        DecisionMemoryRecord(
          id: 'c-3',
          timestamp: t3,
          categoryId: 'Travel',
          amount: 3000,
          recommendationTier: SpendingRecommendationTier.spend,
          userAction: DecisionUserAction.proceeded,
          verdictLine: 'OK',
        ),
      );

      final diningDecisions = await repository.getByCategory('DINING');
      expect(diningDecisions.length, 2);
      expect(diningDecisions[0].id, 'c-2');
      expect(diningDecisions[1].id, 'c-1');
    });

    test('5. Similar decisions retrieval matches category and amount within tolerance', () async {
      // Base: ₹1,000 target amount. With 30% tolerance => [₹700, ₹1,300]
      await repository.recordDecision(
        DecisionMemoryRecord(
          id: 's-1',
          timestamp: t1,
          categoryId: 'electronics',
          amount: 950, // within range
          recommendationTier: SpendingRecommendationTier.thinkAgain,
          userAction: DecisionUserAction.cancelled,
          verdictLine: 'Think again',
        ),
      );
      await repository.recordDecision(
        DecisionMemoryRecord(
          id: 's-2',
          timestamp: t2,
          categoryId: 'electronics',
          amount: 2500, // out of range
          recommendationTier: SpendingRecommendationTier.avoid,
          userAction: DecisionUserAction.cancelled,
          verdictLine: 'Avoid',
        ),
      );
      await repository.recordDecision(
        DecisionMemoryRecord(
          id: 's-3',
          timestamp: t3,
          categoryId: 'electronics',
          amount: 1100, // within range
          recommendationTier: SpendingRecommendationTier.spend,
          userAction: DecisionUserAction.proceeded,
          verdictLine: 'OK',
        ),
      );

      final similar = await repository.getSimilarDecisions(
        categoryId: 'electronics',
        amount: 1000,
        tolerancePercentage: 30.0,
      );

      expect(similar.length, 2);
      expect(similar[0].id, 's-3');
      expect(similar[1].id, 's-1');
    });

    test('6. getById and deleteDecision operate correctly', () async {
      final r = DecisionMemoryRecord(
        id: 'target-id',
        timestamp: t1,
        categoryId: 'bills',
        amount: 1500,
        recommendationTier: SpendingRecommendationTier.spend,
        userAction: DecisionUserAction.proceeded,
        verdictLine: 'OK',
        allowanceState: AllowanceState.comfortable,
        affordabilityStatus: AffordabilityStatus.comfortable,
      );

      await repository.recordDecision(r);

      final fetched = await repository.getById('target-id');
      expect(fetched, isNotNull);
      expect(fetched!.amount, 1500.0);
      expect(fetched.allowanceState, AllowanceState.comfortable);

      await repository.deleteDecision('target-id');
      expect(await repository.getById('target-id'), isNull);
    });

    test('7. clearAll deletes all stored records', () async {
      await repository.recordDecision(
        DecisionMemoryRecord(
          id: 'clear-1',
          timestamp: t1,
          categoryId: 'cat',
          amount: 10,
          recommendationTier: SpendingRecommendationTier.spend,
          userAction: DecisionUserAction.proceeded,
          verdictLine: 'OK',
        ),
      );

      expect((await repository.getAll()).length, 1);
      await repository.clearAll();
      expect(await repository.getAll(), isEmpty);
    });
  });
}
