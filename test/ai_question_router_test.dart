// Focused tests for the deterministic AI question router (PHASE 4).
import 'package:flutter_test/flutter_test.dart';
import 'package:paysense/features/ai/services/ai_question_router.dart';

void main() {
  test('14. a planning question routes to financialPlanning', () {
    final categories = classifyQuestion('What should I do with my next salary?');
    expect(categories, contains(FinancialQuestionCategory.financialPlanning));
  });

  test('15. a budget question routes to budget', () {
    final categories = classifyQuestion('Am I overspending my budget this month?');
    expect(categories, contains(FinancialQuestionCategory.budget));
  });

  test('16. a savings question routes to savings', () {
    final categories = classifyQuestion('How much should I save every month?');
    expect(categories, contains(FinancialQuestionCategory.savings));
  });

  test('17. a debt question routes to debt', () {
    final categories = classifyQuestion('How can I pay off my loans faster?');
    expect(categories, contains(FinancialQuestionCategory.debt));
  });

  test('18. a goal question routes to goals', () {
    final categories = classifyQuestion('Am I on track for my goals?');
    expect(categories, contains(FinancialQuestionCategory.goals));
  });

  test('19. a safe-to-spend question routes to safeToSpend', () {
    final categories = classifyQuestion('Can I afford to spend today?');
    expect(categories, contains(FinancialQuestionCategory.safeToSpend));
  });

  test('an ambiguous/unrecognized question falls back to general (broad context)', () {
    final categories = classifyQuestion('asdkjhaskjdh random gibberish');
    expect(categories, {FinancialQuestionCategory.general});
  });

  test('a question can match multiple categories at once', () {
    final categories = classifyQuestion('How much will I have after my upcoming bills?');
    expect(categories, contains(FinancialQuestionCategory.cashFlow));
    expect(categories, contains(FinancialQuestionCategory.bills));
  });

  test('an emergency fund question routes to emergencyFund specifically', () {
    final categories = classifyQuestion('When will I complete my emergency fund?');
    expect(categories, contains(FinancialQuestionCategory.emergencyFund));
  });

  test('a subscriptions question routes to subscriptions', () {
    final categories = classifyQuestion('Should I cancel my Netflix subscription?');
    expect(categories, contains(FinancialQuestionCategory.subscriptions));
  });

  test('a tax question routes to the taxPlanning placeholder category', () {
    final categories = classifyQuestion('How much income tax will I owe this year?');
    expect(categories, contains(FinancialQuestionCategory.taxPlanning));
  });

  test('question matching is case-insensitive', () {
    final categories = classifyQuestion('CAN I AFFORD THIS?');
    expect(categories, contains(FinancialQuestionCategory.safeToSpend));
  });
}
