// Focused tests for WhatIfIntentParser (PHASE 2/3/4/12/13/17) — pure
// text-only parsing, no repository/Hive access at all. Synthetic questions
// only; nothing here touches real financial data.
import 'package:flutter_test/flutter_test.dart';
import 'package:paysense/features/ai/services/what_if_intent_parser.dart';

void main() {
  group('1. Save-more intent', () {
    test('"What if I save ₹5,000 more every month?" is increaseSavings, high confidence', () {
      final intent = WhatIfIntentParser.parse('What if I save ₹5,000 more every month?');
      expect(intent.type, WhatIfIntentType.increaseSavings);
      expect(intent.confidence, WhatIfConfidence.high);
    });
  });

  group('2. Save-more amount extraction', () {
    test('"What if I save 5000 more each month?" extracts amount=5000 (bare number, no marker)', () {
      final intent = WhatIfIntentParser.parse('What if I save 5000 more each month?');
      expect(intent.type, WhatIfIntentType.increaseSavings);
      expect(intent.amount, 5000);
      expect(intent.confidence, WhatIfConfidence.high);
    });
  });

  group('3. Save-more ₹ format', () {
    test('₹5,000 (with comma) parses to 5000', () {
      final intent = WhatIfIntentParser.parse('What if I save ₹5,000 more every month?');
      expect(intent.amount, 5000);
    });

    test('₹5000 (no comma) parses to 5000', () {
      final intent = WhatIfIntentParser.parse('What if I save ₹5000 more every month?');
      expect(intent.amount, 5000);
    });
  });

  group('4. Save-more Rs format', () {
    test('"Rs. 5,000" parses to 5000', () {
      final intent = WhatIfIntentParser.parse('What if I save Rs. 5,000 more every month?');
      expect(intent.amount, 5000);
    });

    test('"Rs 5000" (no dot) parses to 5000', () {
      final intent = WhatIfIntentParser.parse('What if I save Rs 5000 more every month?');
      expect(intent.amount, 5000);
    });
  });

  group('5. Save-more INR format', () {
    test('"INR 5000" parses to 5000', () {
      final intent = WhatIfIntentParser.parse('What if I save INR 5000 more every month?');
      expect(intent.amount, 5000);
    });
  });

  group('6. 5k parsing', () {
    test('"5k" parses to 5000 with an explicit marker', () {
      final intent = WhatIfIntentParser.parse('What if I save 5k more every month?');
      expect(intent.amount, 5000);
      expect(intent.confidence, WhatIfConfidence.high);
    });

    test('"10K" (capital) also parses to 10000', () {
      final intent = WhatIfIntentParser.parse('What if I save 10K more every month?');
      expect(intent.amount, 10000);
    });
  });

  group('7. 1.5 lakh parsing', () {
    test('"1.5 lakh" parses to 150000', () {
      final intent = WhatIfIntentParser.parse('What if I save 1.5 lakh more every month?');
      expect(intent.amount, 150000);
    });

    test('"₹1.5L" (capital L suffix) parses to 150000', () {
      final intent = WhatIfIntentParser.parse('What if I save ₹1.5L more every month?');
      expect(intent.amount, 150000);
    });

    test('"2 lakh" parses to 200000', () {
      final intent = WhatIfIntentParser.parse('When will I reach ₹2 lakh?');
      expect(intent.type, WhatIfIntentType.reachGoal);
      expect(intent.targetAmount, 200000);
    });
  });

  group('8. Expense reduction amount', () {
    test('"What if I reduce my expenses by ₹3,000?" is decreaseExpenses with a negative amount', () {
      final intent = WhatIfIntentParser.parse('What if I reduce my expenses by ₹3,000?');
      expect(intent.type, WhatIfIntentType.decreaseExpenses);
      expect(intent.amount, -3000);
      expect(intent.confidence, WhatIfConfidence.high);
    });
  });

  group('9. Expense reduction percentage', () {
    test('"What if I reduce my expenses by 10%?" is decreaseExpenses with percentage=-10', () {
      final intent = WhatIfIntentParser.parse('What if I reduce my expenses by 10%?');
      expect(intent.type, WhatIfIntentType.decreaseExpenses);
      expect(intent.percentage, -10);
      expect(intent.amount, isNull);
    });
  });

  group('10. Category reduction', () {
    test('"What if I spend 20% less on food?" is reduceCategorySpending, category=food, percentage=20', () {
      final intent = WhatIfIntentParser.parse('What if I spend 20% less on food?');
      expect(intent.type, WhatIfIntentType.reduceCategorySpending);
      expect(intent.categoryText, 'food');
      expect(intent.percentage, 20);
      expect(intent.confidence, WhatIfConfidence.high);
    });

    test('a generic expense reduction with no category never fires the category branch', () {
      final intent = WhatIfIntentParser.parse('What if I reduce my expenses by ₹3,000?');
      expect(intent.type, WhatIfIntentType.decreaseExpenses);
    });
  });

  group('14. Extra loan payment', () {
    test('"What if I pay ₹20,000 extra toward my loan?" is extraLoanPayment, amount=20000, no loan name', () {
      final intent = WhatIfIntentParser.parse('What if I pay ₹20,000 extra toward my loan?');
      expect(intent.type, WhatIfIntentType.extraLoanPayment);
      expect(intent.amount, 20000);
      expect(intent.loanText, isNull); // "my loan" is generic — never a fake name candidate
      expect(intent.confidence, WhatIfConfidence.high);
    });

    test('a named loan is captured as a real candidate string, filler words stripped', () {
      final intent = WhatIfIntentParser.parse(
        'What if I pay ₹20,000 extra toward my personal loan?',
      );
      expect(intent.loanText, 'personal');
    });
  });

  group('22. Missing parameter clarification', () {
    test('"What if I save more every month?" (no amount) asks instead of guessing', () {
      final intent = WhatIfIntentParser.parse('What if I save more every month?');
      expect(intent.type, WhatIfIntentType.increaseSavings);
      expect(intent.confidence, WhatIfConfidence.medium);
      expect(intent.amount, isNull);
      expect(intent.clarificationPrompt, isNotNull);
      expect(intent.isActionable, isFalse); // medium confidence is never auto-calculated
    });

    test('"save 5" (tiny bare number, no marker) is treated as ambiguous, not ₹5,000', () {
      final intent = WhatIfIntentParser.parse('What if I save 5 more every month?');
      expect(intent.confidence, WhatIfConfidence.medium);
      expect(intent.amount, isNull);
    });
  });

  group('23. Low-confidence fallback', () {
    test('"Why did my expenses increase?" has no hypothetical trigger — falls through to none', () {
      final intent = WhatIfIntentParser.parse('Why did my expenses increase?');
      expect(intent.type, WhatIfIntentType.none);
      expect(intent.confidence, WhatIfConfidence.low);
      expect(intent.isActionable, isFalse);
    });

    test('"What is an emergency fund?" (definitional "what is") is never a what-if scenario', () {
      final intent = WhatIfIntentParser.parse('What is an emergency fund?');
      expect(intent.type, WhatIfIntentType.none);
    });

    test('"What is a credit score?" is never a what-if scenario', () {
      final intent = WhatIfIntentParser.parse('What is a credit score?');
      expect(intent.type, WhatIfIntentType.none);
    });

    test('a literal "tax" mention always short-circuits to none, even with a hypothetical trigger', () {
      final intent = WhatIfIntentParser.parse('What if I invest ₹50,000 for tax saving?');
      expect(intent.type, WhatIfIntentType.none);
    });

    test('"When will I complete my emergency fund?" IS a what-if question despite no "what if"', () {
      final intent = WhatIfIntentParser.parse('When will I complete my emergency fund?');
      expect(intent.type, WhatIfIntentType.reachEmergencyFund);
    });
  });
}
