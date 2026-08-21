// Focused tests for AffordabilityIntentParser (PHASE 6) — pure text
// parsing, no repository access. Synthetic questions only.
import 'package:flutter_test/flutter_test.dart';
import 'package:paysense/features/ai/services/affordability_intent_parser.dart';

void main() {
  group('26. ₹90,000', () {
    test('"Can I afford a ₹90,000 phone?" extracts amount=90000 and item="phone"', () {
      final intent = AffordabilityIntentParser.parse('Can I afford a ₹90,000 phone?');
      expect(intent.type, AffordabilityIntentType.canAfford);
      expect(intent.amount, 90000);
      expect(intent.itemDescription, 'phone');
      expect(intent.confidence, AffordabilityConfidence.high);
    });
  });

  group('27. ₹90000', () {
    test('no comma still parses to 90000', () {
      final intent = AffordabilityIntentParser.parse('Can I afford a ₹90000 phone?');
      expect(intent.amount, 90000);
    });
  });

  group('28. Rs 90,000', () {
    test('"Rs" prefix parses to 90000', () {
      final intent = AffordabilityIntentParser.parse('Can I afford a Rs 90,000 phone?');
      expect(intent.amount, 90000);
    });
  });

  group('29. 90k', () {
    test('"Can I buy a 50k laptop?" extracts amount=50000 and item="laptop"', () {
      final intent = AffordabilityIntentParser.parse('Can I buy a 50k laptop?');
      expect(intent.amount, 50000);
      expect(intent.itemDescription, 'laptop');
    });
  });

  group('30. 1.5 lakh', () {
    test('"Can I afford this 1.5 lakh bike?" extracts amount=150000 and item="bike"', () {
      final intent = AffordabilityIntentParser.parse('Can I afford this 1.5 lakh bike?');
      expect(intent.amount, 150000);
      expect(intent.itemDescription, 'bike');
    });
  });

  group('31. ₹1.5L', () {
    test('capital L suffix parses to 150000', () {
      final intent = AffordabilityIntentParser.parse('Can I afford a ₹1.5L bike?');
      expect(intent.amount, 150000);
    });
  });

  group("Is it okay to spend / on X", () {
    test('"Is it okay to spend 20000 on a trip?" extracts amount=20000 and item="trip"', () {
      final intent = AffordabilityIntentParser.parse('Is it okay to spend 20000 on a trip?');
      expect(intent.amount, 20000);
      expect(intent.itemDescription, 'trip');
    });

    test('"Should I spend ₹30,000 on a phone?" extracts amount=30000 and item="phone"', () {
      final intent = AffordabilityIntentParser.parse('Should I spend ₹30,000 on a phone?');
      expect(intent.amount, 30000);
      expect(intent.itemDescription, 'phone');
    });
  });

  group('32. Ambiguous small number', () {
    test('a bare small number with no marker asks for clarification instead of guessing', () {
      final intent = AffordabilityIntentParser.parse('Can I afford this for 5?');
      expect(intent.confidence, AffordabilityConfidence.medium);
      expect(intent.amount, isNull);
      expect(intent.clarificationPrompt, isNotNull);
      expect(intent.isActionable, isFalse);
    });

    test('no amount at all falls through to none, not a clarification', () {
      final intent = AffordabilityIntentParser.parse('Can I afford to spend today?');
      expect(intent.type, AffordabilityIntentType.none);
    });
  });

  group('33. Normal financial question unaffected', () {
    test('"Can I afford to spend today?" (existing quick question) is never hijacked', () {
      final intent = AffordabilityIntentParser.parse('Can I afford to spend today?');
      expect(intent.type, AffordabilityIntentType.none);
      expect(intent.isActionable, isFalse);
    });

    test('"How am I doing this month?" is unrelated and falls through to none', () {
      final intent = AffordabilityIntentParser.parse('How am I doing this month?');
      expect(intent.type, AffordabilityIntentType.none);
    });

    test('"Why did my expenses increase?" is unrelated and falls through to none', () {
      final intent = AffordabilityIntentParser.parse('Why did my expenses increase?');
      expect(intent.type, AffordabilityIntentType.none);
    });
  });
}
