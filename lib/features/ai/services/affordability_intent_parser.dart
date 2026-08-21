import 'package:flutter/foundation.dart';

import 'what_if_intent_parser.dart' show AmountParser;

/// FINANCIAL ACTION ENGINE 1.0 / "CAN I AFFORD THIS?" — PHASE 6.
/// A sibling to [WhatIfIntentParser]/`TaxIntentParser`, not a merge into
/// either: affordability questions ("Can I afford a ₹90,000 phone?") have
/// their own distinct trigger phrasing and only ever need one number (a
/// purchase price) plus an optional free-text label, so a dedicated small
/// parser stays simpler than bolting a third concern onto either existing
/// one. Pure text parsing, no repository access — reuses [AmountParser]
/// as-is rather than re-implementing currency parsing.
enum AffordabilityIntentType { canAfford, none }

enum AffordabilityConfidence { high, medium, low }

@immutable
class AffordabilityIntent {
  const AffordabilityIntent({
    required this.type,
    required this.confidence,
    required this.originalQuestion,
    this.amount,
    this.itemDescription,
    this.clarificationPrompt,
  });

  const AffordabilityIntent.none(this.originalQuestion)
    : type = AffordabilityIntentType.none,
      confidence = AffordabilityConfidence.low,
      amount = null,
      itemDescription = null,
      clarificationPrompt = null;

  final AffordabilityIntentType type;
  final AffordabilityConfidence confidence;
  final String originalQuestion;
  final double? amount;
  final String? itemDescription;
  final String? clarificationPrompt;

  bool get isActionable => type != AffordabilityIntentType.none && confidence == AffordabilityConfidence.high;
}

class AffordabilityIntentParser {
  AffordabilityIntentParser._();

  static final List<String> _triggerPhrases = [
    'can i afford', 'can i buy', 'should i spend', 'should i buy',
    'is it okay to spend', 'is it ok to spend', 'can we afford',
  ];

  static AffordabilityIntent parse(String question) {
    final normalized = question.toLowerCase().trim();
    if (!_triggerPhrases.any(normalized.contains)) {
      return AffordabilityIntent.none(question);
    }

    final parsed = AmountParser.parse(question);
    if (parsed == null) {
      // No amount anywhere in the question — e.g. the existing "Can I
      // afford to spend today?" quick question is a general safe-to-spend
      // question, not about a specific priced item. Falling through to
      // `none` here (rather than interrupting with "how much does it
      // cost?") preserves that question's existing behavior unchanged.
      return AffordabilityIntent.none(question);
    }

    // Same "never silently interpret ambiguous small numbers" rule as
    // WhatIfIntentParser: a bare, unmarked number under 100 is far more
    // likely a typo/partial thought than a real purchase price.
    if (!parsed.hadExplicitMarker && parsed.value < 100) {
      return AffordabilityIntent(
        type: AffordabilityIntentType.canAfford,
        confidence: AffordabilityConfidence.medium,
        originalQuestion: question,
        clarificationPrompt: 'How much does it cost?',
      );
    }

    return AffordabilityIntent(
      type: AffordabilityIntentType.canAfford,
      confidence: AffordabilityConfidence.high,
      originalQuestion: question,
      amount: parsed.value,
      itemDescription: _extractItemDescription(normalized),
    );
  }

  static String? _extractItemDescription(String normalized) {
    final onMatch = RegExp(
      r'on\s+(?:a\s+|an\s+|this\s+|my\s+)?([a-z ]+?)[?.!]?$',
    ).firstMatch(normalized);
    final onCandidate = onMatch?.group(1)?.trim();
    if (onCandidate != null && onCandidate.isNotEmpty) return onCandidate;

    final afterAmountMatch = RegExp(
      r'(?:₹|rs\.?|inr)?\s*[\d,]+(?:\.\d+)?\s*(?:k|lakhs?|crores?|cr|l)?\s+'
      r'(?:a\s+|an\s+|this\s+)?([a-z ]+?)[?.!]?$',
      caseSensitive: false,
    ).firstMatch(normalized);
    final candidate = afterAmountMatch?.group(1)?.trim();
    return (candidate != null && candidate.isNotEmpty) ? candidate : null;
  }
}
