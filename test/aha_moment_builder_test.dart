// Pure tests for AhaMomentBuilder (Consumer Monetization Foundation,
// PHASE 3/16). Built via the REAL FinancialActionEngine/FinancialInsightEngine
// output shapes (synthetic instances), never a duplicate selection formula.
import 'package:flutter_test/flutter_test.dart';
import 'package:paysense/shared/utils/aha_moment_builder.dart';
import 'package:paysense/shared/utils/financial_action_engine.dart';
import 'package:paysense/shared/utils/financial_insight_engine.dart';

FinancialAction _action({
  required ActionPriority priority,
  required String title,
  String explanation = 'explanation',
  String recommendedAction = 'do something',
}) {
  return FinancialAction(
    priority: priority,
    category: ActionCategory.budget,
    actionType: ActionType.overBudget,
    title: title,
    explanation: explanation,
    recommendedAction: recommendedAction,
  );
}

FinancialInsight _insight({
  required InsightPriority priority,
  required String title,
  String explanation = 'insight explanation',
}) {
  return FinancialInsight(
    id: 'i-$title',
    type: InsightType.unusualCategorySpending,
    priority: priority,
    title: title,
    explanation: explanation,
    recommendedAction: 'review spending',
  );
}

void main() {
  group('AhaMomentBuilder selection', () {
    test('an empty account (no actions, no insights) reports insufficient data', () {
      final result = AhaMomentBuilder.build(actions: const [], insights: const []);
      expect(result.hasSufficientData, isFalse);
      expect(result.riskTitle, isNull);
      expect(result.nextBestMoveTitle, isNull);
    });

    test('a critical action becomes the risk and the next best move', () {
      final action = _action(priority: ActionPriority.critical, title: 'Emergency fund gap');
      final result = AhaMomentBuilder.build(actions: [action], insights: const []);
      expect(result.riskTitle, 'Emergency fund gap');
      expect(result.nextBestMoveTitle, 'Emergency fund gap');
      expect(result.nextBestMoveAction, action.recommendedAction);
    });

    test('a positive action becomes "doing well", never mistaken for a risk', () {
      final action = _action(priority: ActionPriority.positive, title: 'On track');
      final result = AhaMomentBuilder.build(actions: [action], insights: const []);
      expect(result.doingWellTitle, 'On track');
      expect(result.riskTitle, isNull);
    });

    test('a medium action becomes the opportunity slot', () {
      final action = _action(priority: ActionPriority.medium, title: 'Near budget limit');
      final result = AhaMomentBuilder.build(actions: [action], insights: const []);
      expect(result.opportunityTitle, 'Near budget limit');
    });

    test('when no action fills a slot, an insight of matching severity fills it instead', () {
      final insight = _insight(priority: InsightPriority.high, title: 'Spending spike');
      final result = AhaMomentBuilder.build(actions: const [], insights: [insight]);
      expect(result.riskTitle, 'Spending spike');
      expect(result.hasSufficientData, isTrue);
    });

    test('the SAME critical action never fills both the risk and opportunity slots', () {
      final critical = _action(priority: ActionPriority.critical, title: 'Critical issue');
      final result = AhaMomentBuilder.build(actions: [critical], insights: const []);
      expect(result.riskTitle, 'Critical issue');
      expect(result.opportunityTitle, isNull);
    });

    test('risk/opportunity/doingWell can all be populated simultaneously from a full action plan', () {
      final actions = [
        _action(priority: ActionPriority.critical, title: 'Risk item'),
        _action(priority: ActionPriority.medium, title: 'Opportunity item'),
      ];
      final insights = [_insight(priority: InsightPriority.positive, title: 'Doing well item')];
      final result = AhaMomentBuilder.build(actions: actions, insights: insights);
      expect(result.riskTitle, 'Risk item');
      expect(result.opportunityTitle, 'Opportunity item');
      expect(result.doingWellTitle, 'Doing well item');
    });

    test('the next best move falls back to the first action when nothing is critical/high', () {
      final action = _action(priority: ActionPriority.medium, title: 'Only action');
      final result = AhaMomentBuilder.build(actions: [action], insights: const []);
      expect(result.nextBestMoveTitle, 'Only action');
    });
  });

  group('15. No repository mutation', () {
    test('build() never mutates its input lists', () {
      final actions = [_action(priority: ActionPriority.critical, title: 'X')];
      final insights = [_insight(priority: InsightPriority.high, title: 'Y')];
      final actionsBefore = List.of(actions);
      final insightsBefore = List.of(insights);

      AhaMomentBuilder.build(actions: actions, insights: insights);

      expect(actions, actionsBefore);
      expect(insights, insightsBefore);
    });
  });
}
