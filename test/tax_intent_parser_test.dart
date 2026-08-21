// Focused tests for TaxIntentParser (PHASE 10/11/12) — pure text parsing,
// no repository access. Synthetic questions only.
import 'package:flutter_test/flutter_test.dart';
import 'package:paysense/features/ai/services/tax_intent_parser.dart';

void main() {
  group('Direct tax estimate questions', () {
    test('"How much tax will I pay?" is a bare estimate with no stated regime', () {
      final intent = TaxIntentParser.parse('How much tax will I pay?');
      expect(intent.type, TaxIntentType.estimate);
      expect(intent.regimeChoice, isNull);
    });

    test('"How much tax do I owe?" is also an estimate', () {
      final intent = TaxIntentParser.parse('How much tax do I owe?');
      expect(intent.type, TaxIntentType.estimate);
    });

    test('an estimate question naming "new regime" carries that choice', () {
      final intent = TaxIntentParser.parse('How much tax will I pay under the new regime?');
      expect(intent.type, TaxIntentType.estimate);
      expect(intent.regimeChoice, TaxIntentRegimeChoice.newRegime);
    });
  });

  group('Monthly tax provision', () {
    test('"How much tax should I keep aside?" is monthlyProvision, not a generic estimate', () {
      final intent = TaxIntentParser.parse('How much tax should I keep aside?');
      expect(intent.type, TaxIntentType.monthlyProvision);
    });
  });

  group('Regime comparison', () {
    test('"Compare old and new regime" is compareRegimes', () {
      final intent = TaxIntentParser.parse('Compare old and new regime');
      expect(intent.type, TaxIntentType.compareRegimes);
    });

    test('"What if I compare old and new regime?" is also compareRegimes', () {
      final intent = TaxIntentParser.parse('What if I compare old and new regime?');
      expect(intent.type, TaxIntentType.compareRegimes);
    });
  });

  group('Tax what-if: salary', () {
    test('"What if my salary becomes ₹15 lakh?" is whatIfSalary with amount=1500000', () {
      final intent = TaxIntentParser.parse('What if my salary becomes ₹15 lakh?');
      expect(intent.type, TaxIntentType.whatIfSalary);
      expect(intent.amount, 1500000);
    });

    test('a plain "what is my average salary" question is never treated as a tax scenario', () {
      final intent = TaxIntentParser.parse("What's my average salary this month?");
      expect(intent.type, TaxIntentType.none);
    });
  });

  group('Tax what-if: 80C', () {
    test('"What if I invest ₹1.5 lakh under 80C?" is whatIf80C with amount=150000', () {
      final intent = TaxIntentParser.parse('What if I invest ₹1.5 lakh under 80C?');
      expect(intent.type, TaxIntentType.whatIf80C);
      expect(intent.amount, 150000);
    });
  });

  group('Tax what-if: 80D', () {
    test('"What if I claim ₹50,000 under 80D?" is whatIf80D with amount=50000', () {
      final intent = TaxIntentParser.parse('What if I claim ₹50,000 under 80D?');
      expect(intent.type, TaxIntentType.whatIf80D);
      expect(intent.amount, 50000);
    });
  });

  group('Tax what-if: home-loan interest', () {
    test('"What if I pay ₹2 lakh home-loan interest?" is whatIfHomeLoanInterest with amount=200000', () {
      final intent = TaxIntentParser.parse('What if I pay ₹2 lakh home-loan interest?');
      expect(intent.type, TaxIntentType.whatIfHomeLoanInterest);
      expect(intent.amount, 200000);
    });
  });

  group('Definitional questions never trigger a calculation', () {
    test('"What is a tax deduction?" falls through to none', () {
      final intent = TaxIntentParser.parse('What is a tax deduction?');
      expect(intent.type, TaxIntentType.none);
    });

    test('"What is an emergency fund?" is unrelated and falls through to none', () {
      final intent = TaxIntentParser.parse('What is an emergency fund?');
      expect(intent.type, TaxIntentType.none);
    });
  });

  group('Non-tax questions are never misclassified', () {
    test('"Why did my expenses increase?" is none', () {
      final intent = TaxIntentParser.parse('Why did my expenses increase?');
      expect(intent.type, TaxIntentType.none);
      expect(intent.isActionable, isFalse);
    });
  });
}
