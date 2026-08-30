import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paysense/features/dashboard/widgets/spending_pattern_card.dart';
import 'package:paysense/shared/models/spending_pattern.dart';
import 'package:paysense/shared/providers/spending_patterns_provider.dart';

void main() {
  group('SpendingPatternCard Widget Tests', () {
    testWidgets('1. Renders section title and subtitle', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            spendingPatternsWithMemoryProvider.overrideWith(
              (ref) => Future.value(const [
                SpendingPattern(
                  type: SpendingPatternType.insufficientHistory,
                  title: 'Building your spending patterns',
                  description: 'Keep tracking your daily expenses to discover your repeated spending habits.',
                ),
              ]),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: SpendingPatternCard(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Your Spending Patterns'), findsOneWidget);
      expect(find.text('Notice where your money is repeatedly going.'), findsOneWidget);
      expect(find.text('Building your spending patterns'), findsOneWidget);
    });

    testWidgets('2. Renders list of detected spending patterns with badges', (tester) async {
      final samplePatterns = [
        const SpendingPattern(
          type: SpendingPatternType.frequentCategory,
          title: 'Dining appears frequently',
          description: "You've made 8 dining purchases in the last 30 days.",
          occurrenceCount: 8,
          priority: 9,
        ),
        const SpendingPattern(
          type: SpendingPatternType.increasingCategory,
          title: 'Travel spending is increasing',
          description: 'Travel spending is higher than the previous 30-day period.',
          percentageChange: 45.0,
          priority: 8,
        ),
        const SpendingPattern(
          type: SpendingPatternType.smallPurchaseFrequency,
          title: 'Small purchases add up',
          description: '7 small purchases totaled ₹1,250 across the month.',
          occurrenceCount: 7,
          priority: 6,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            spendingPatternsWithMemoryProvider.overrideWith(
              (ref) => Future.value(samplePatterns),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: SpendingPatternCard(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Dining appears frequently'), findsOneWidget);
      expect(find.text("You've made 8 dining purchases in the last 30 days."), findsOneWidget);
      expect(find.text('Travel spending is increasing'), findsOneWidget);
      expect(find.text('+45%'), findsOneWidget);
      expect(find.text('Small purchases add up'), findsOneWidget);
    });

    testWidgets('3. Renders empty state gracefully when patterns list is empty', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            spendingPatternsWithMemoryProvider.overrideWith(
              (ref) => Future.value(const []),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: SpendingPatternCard(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Your Spending Patterns'), findsOneWidget);
      expect(find.text('Keep logging transactions to discover your spending patterns.'), findsOneWidget);
    });
  });
}
