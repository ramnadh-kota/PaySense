import 'package:flutter/foundation.dart';

/// Deterministic "what if?" scenario types the AI Financial Assistant can
/// answer with a real calculator instead of LLM arithmetic. `none` means
/// the question isn't a what-if scenario at all (or isn't confidently one)
/// — callers must treat that identically to "use the normal AI flow".
enum WhatIfIntentType {
  increaseSavings,
  decreaseExpenses,
  reduceCategorySpending,
  extraLoanPayment,
  stopSubscription,
  reachGoal,
  reachEmergencyFund,
  none,
}

/// - [high]: enough information to calculate automatically.
/// - [medium]: a recognized what-if shape, but missing one required
///   parameter (e.g. no amount) — ask a clarifying question, never guess.
/// - [low]: not confidently a what-if question — use the normal AI route.
enum WhatIfConfidence { high, medium, low }

/// The output of text-only parsing (PHASE 2/3/4) — no repository access, no
/// entity resolution. [categoryText]/[loanText]/[subscriptionText] are raw
/// candidate substrings from the question, not yet matched against real
/// data; that happens in `WhatIfOrchestrator` (PHASE 5/6/7), which is the
/// only place allowed to turn a candidate into a real id.
@immutable
class WhatIfIntent {
  const WhatIfIntent({
    required this.type,
    required this.confidence,
    required this.originalQuestion,
    this.amount,
    this.percentage,
    this.categoryText,
    this.loanText,
    this.subscriptionText,
    this.targetAmount,
    this.clarificationPrompt,
  });

  const WhatIfIntent.none(this.originalQuestion)
    : type = WhatIfIntentType.none,
      confidence = WhatIfConfidence.low,
      amount = null,
      percentage = null,
      categoryText = null,
      loanText = null,
      subscriptionText = null,
      targetAmount = null,
      clarificationPrompt = null;

  final WhatIfIntentType type;
  final WhatIfConfidence confidence;
  final String originalQuestion;

  final double? amount;
  final double? percentage;
  final String? categoryText;
  final String? loanText;
  final String? subscriptionText;
  final double? targetAmount;

  /// Set only when [confidence] is [WhatIfConfidence.medium] — the exact
  /// question to show the user instead of guessing (PHASE 13).
  final String? clarificationPrompt;

  /// True only when there's enough information to calculate immediately
  /// (PHASE 13's HIGH tier) — medium confidence still needs a clarifying
  /// question first (see [clarificationPrompt]), and is deliberately NOT
  /// "actionable" by this definition.
  bool get isActionable => type != WhatIfIntentType.none && confidence == WhatIfConfidence.high;
}

/// A parsed amount plus whether it had an explicit currency/unit marker
/// (₹, Rs, INR, k, lakh, crore, "rupees") — a bare number with no marker
/// is still parsed literally (never multiplied up), but is flagged so
/// callers can be more cautious about implausibly small bare values (see
/// [WhatIfIntentParser]'s "save 5" handling).
@immutable
class ParsedAmount {
  const ParsedAmount({required this.value, required this.hadExplicitMarker});

  final double value;
  final bool hadExplicitMarker;
}

/// PHASE 4 — Indian currency amount parsing. Deliberately conservative:
/// parses the number exactly as written, never invents a multiplier for a
/// bare number (₹5 stays ₹5, it is never silently reinterpreted as ₹5,000).
class AmountParser {
  AmountParser._();

  static const Map<String, double> _unitMultipliers = {
    'k': 1000,
    'lakh': 100000,
    'lakhs': 100000,
    'crore': 10000000,
    'cr': 10000000,
  };

  /// ₹1.5L / ₹2L — case-SENSITIVE capital L immediately after the digits,
  /// so this never matches a stray lowercase "l" inside an ordinary word.
  static final RegExp _capitalLSuffix = RegExp(r'([\d,]+(?:\.\d+)?)L\b');

  /// ₹5,000 / ₹5000 / Rs. 5,000 / Rs 5000 / INR 5000 — an explicit currency
  /// prefix, optionally followed by a k/lakh/crore word unit.
  static final RegExp _prefixedAmount = RegExp(
    r'(?:₹|rs\.?|inr)\s*([\d,]+(?:\.\d+)?)\s*(k|lakhs?|crores?|cr)?\b',
    caseSensitive: false,
  );

  /// 5k / 10K / 1.5 lakh / 2 lakhs / 3 crore — a word/letter unit suffix
  /// with no currency prefix needed.
  static final RegExp _suffixedAmount = RegExp(
    r'([\d,]+(?:\.\d+)?)\s*(k|lakhs?|crores?|cr)\b',
    caseSensitive: false,
  );

  /// "5000 rupees"
  static final RegExp _rupeesSuffix = RegExp(
    r'([\d,]+(?:\.\d+)?)\s*rupees\b',
    caseSensitive: false,
  );

  /// A bare number with no currency/unit marker at all — lowest-confidence
  /// fallback, parsed literally.
  static final RegExp _bareNumber = RegExp(r'([\d,]+(?:\.\d+)?)');

  /// Finds the first (leftmost) amount-like token in [text] using the
  /// marker patterns above, in order of specificity. Returns null when no
  /// numeric token is found at all.
  static ParsedAmount? parse(String text) {
    final capitalL = _capitalLSuffix.firstMatch(text);
    if (capitalL != null) {
      final value = _parseNumber(capitalL.group(1)!);
      if (value != null) {
        return ParsedAmount(value: value * 100000, hadExplicitMarker: true);
      }
    }

    final prefixed = _prefixedAmount.firstMatch(text);
    if (prefixed != null) {
      final value = _parseNumber(prefixed.group(1)!);
      if (value != null) {
        final unit = prefixed.group(2)?.toLowerCase();
        final multiplier = unit == null ? 1.0 : (_unitMultipliers[unit] ?? 1.0);
        return ParsedAmount(value: value * multiplier, hadExplicitMarker: true);
      }
    }

    final suffixed = _suffixedAmount.firstMatch(text);
    if (suffixed != null) {
      final value = _parseNumber(suffixed.group(1)!);
      final unit = suffixed.group(2)?.toLowerCase();
      if (value != null && unit != null) {
        final multiplier = _unitMultipliers[unit] ?? 1.0;
        return ParsedAmount(value: value * multiplier, hadExplicitMarker: true);
      }
    }

    final rupees = _rupeesSuffix.firstMatch(text);
    if (rupees != null) {
      final value = _parseNumber(rupees.group(1)!);
      if (value != null) {
        return ParsedAmount(value: value, hadExplicitMarker: true);
      }
    }

    final bare = _bareNumber.firstMatch(text);
    if (bare != null) {
      final value = _parseNumber(bare.group(1)!);
      if (value != null) {
        return ParsedAmount(value: value, hadExplicitMarker: false);
      }
    }

    return null;
  }

  static double? _parseNumber(String raw) {
    return double.tryParse(raw.replaceAll(',', ''));
  }
}

/// Extracts a percentage ("10%", "20 percent") — kept separate from
/// [AmountParser] so "reduce spending by 20%" never has its "20" mistaken
/// for a ₹20 amount.
class PercentageParser {
  PercentageParser._();

  static final RegExp _percentPattern = RegExp(
    r'(\d+(?:\.\d+)?)\s*(?:%|percent)',
    caseSensitive: false,
  );

  static double? parse(String text) {
    final match = _percentPattern.firstMatch(text);
    if (match == null) return null;
    return double.tryParse(match.group(1)!);
  }

  /// The span the percentage match occupies, so [AmountParser] can be run
  /// against the remaining text without re-finding the same digits as a
  /// bare amount.
  static String stripPercentage(String text) {
    return text.replaceAll(_percentPattern, ' ');
  }
}

/// PHASE 3 — deterministic what-if intent detection. Two-layer gate:
/// 1. A "hypothetical trigger" phrase must be present ("what if", "when
///    will i", "how long until", "how much should i save", "how much more
///    do i need", "suppose i") — this is what separates an *actionable*
///    question ("when will I reach my vacation goal?") from a definitional
///    one ("what is an emergency fund?", "why did my expenses increase?"),
///    satisfying PHASE 12 without an NLP model.
/// 2. Only once (1) passes does the specific scenario TYPE get matched via
///    its own keyword set.
///
/// A literal "tax" mention short-circuits straight to `none` regardless of
/// anything else matched — PHASE 17 always routes tax questions to the
/// normal AI path (which already carries the tax-planning boundary in its
/// system prompt), never to a fabricated calculation here.
class WhatIfIntentParser {
  WhatIfIntentParser._();

  static final List<String> _hypotheticalTriggers = [
    'what if', 'when will i', 'when will my', 'how long until',
    'how much should i save', 'how much more do i need', 'suppose i',
    'if i save', 'if i pay', 'if i stop', 'if i cancel', 'if i reduce',
    'if i cut',
  ];

  static final List<String> _taxKeywords = ['tax', 'itr', 'income tax'];

  static WhatIfIntent parse(String question) {
    final normalized = question.toLowerCase().trim();

    if (_taxKeywords.any(normalized.contains)) {
      // PHASE 17: never invent a tax calculation — always defer to the
      // normal AI path's existing tax-planning boundary.
      return WhatIfIntent.none(question);
    }

    if (!_hypotheticalTriggers.any(normalized.contains)) {
      return WhatIfIntent.none(question);
    }

    // Order matters: more specific scenario shapes are checked before more
    // general ones (e.g. "reduce food spending by 20%" must resolve to
    // reduceCategorySpending, not the more generic decreaseExpenses).
    return _matchStopSubscription(normalized, question) ??
        _matchExtraLoanPayment(normalized, question) ??
        _matchReduceCategorySpending(normalized, question) ??
        _matchDecreaseExpenses(normalized, question) ??
        _matchIncreaseSavings(normalized, question) ??
        _matchReachEmergencyFund(normalized, question) ??
        _matchReachGoal(normalized, question) ??
        WhatIfIntent.none(question);
  }

  /// Generic filler words that mean "no specific name was actually given"
  /// when they're the *entire* captured candidate — e.g. "cancel my
  /// subscription" must resolve to "no candidate", not the literal word
  /// "subscription".
  static const Set<String> _genericFillerWords = {
    '', 'my', 'the', 'a', 'an', 'subscription', 'subscriptions', 'saving', 'savings',
    'recurring', 'recurring payment', 'loan', 'loans', 'emi',
  };

  /// Connector/quantity words that end a captured phrase early — e.g. "on
  /// food by 3000" must yield the category "food", not "food by".
  static const Set<String> _boundaryWords = {
    'by', 'spending', 'expenses', 'expense', 'every', 'each', 'monthly', 'month', 'to',
  };

  /// Strips a leading "my "/"the "/"a "/"an ", truncates at the first
  /// connector word (see [_boundaryWords]), and returns null when nothing
  /// meaningful remains (see [_genericFillerWords]).
  static String? _cleanEntityCandidate(String? candidate) {
    if (candidate == null) return null;
    final stripped = candidate.trim().replaceFirst(RegExp(r'^(my|the|a|an)\s+'), '').trim();
    if (stripped.isEmpty) return null;

    final kept = <String>[];
    for (final word in stripped.split(RegExp(r'\s+'))) {
      if (_boundaryWords.contains(word)) break;
      kept.add(word);
    }
    final result = kept.join(' ');
    return _genericFillerWords.contains(result) || result.isEmpty ? null : result;
  }

  static WhatIfIntent? _matchStopSubscription(String normalized, String original) {
    final stopWords = ['stop', 'cancel', 'unsubscribe from', 'drop'];
    if (!stopWords.any(normalized.contains)) return null;
    if (!(normalized.contains('subscription') ||
        normalized.contains('netflix') ||
        normalized.contains('spotify') ||
        normalized.contains('prime') ||
        normalized.contains('recurring'))) {
      return null;
    }

    // Capture everything between the trigger verb and the end of the
    // sentence (dropping a trailing "subscription" word and punctuation),
    // then clean it in plain Dart rather than relying on regex
    // backtracking to reject filler words — much easier to reason about
    // correctly than a single do-everything pattern.
    final match = RegExp(
      r'(?:stop|cancel|unsubscribe from|drop)\s+([a-z0-9 ]+?)[?.!]?$',
    ).firstMatch(normalized);
    var candidate = match?.group(1)?.trim();
    candidate = candidate?.replaceFirst(RegExp(r'\s+subscription$'), '').trim();
    final cleaned = _cleanEntityCandidate(candidate);

    return WhatIfIntent(
      type: WhatIfIntentType.stopSubscription,
      confidence: cleaned == null ? WhatIfConfidence.medium : WhatIfConfidence.high,
      originalQuestion: original,
      subscriptionText: cleaned,
      clarificationPrompt: cleaned == null
          ? 'Which subscription would you like to simulate stopping?'
          : null,
    );
  }

  static WhatIfIntent? _matchExtraLoanPayment(String normalized, String original) {
    final hasLoanWord = normalized.contains('loan') || normalized.contains('emi');
    final hasExtraPaymentPhrase = normalized.contains('extra') || normalized.contains('additional');
    final hasPayWord = normalized.contains('pay');
    if (!hasLoanWord || !hasExtraPaymentPhrase || !hasPayWord) return null;

    final amount = AmountParser.parse(original);
    String? loanText;
    final loanNameMatch = RegExp(
      r'(?:toward|towards|on|for)\s+([a-z ]+?)\s*loan',
    ).firstMatch(normalized);
    if (loanNameMatch != null) {
      loanText = _cleanEntityCandidate(loanNameMatch.group(1));
    }

    if (amount == null) {
      return WhatIfIntent(
        type: WhatIfIntentType.extraLoanPayment,
        confidence: WhatIfConfidence.medium,
        originalQuestion: original,
        loanText: loanText,
        clarificationPrompt: 'How much extra would you like to pay toward the loan?',
      );
    }

    if (!amount.hadExplicitMarker && amount.value < 100) {
      return WhatIfIntent(
        type: WhatIfIntentType.extraLoanPayment,
        confidence: WhatIfConfidence.medium,
        originalQuestion: original,
        loanText: loanText,
        clarificationPrompt: 'How much extra would you like to pay toward the loan?',
      );
    }

    return WhatIfIntent(
      type: WhatIfIntentType.extraLoanPayment,
      confidence: WhatIfConfidence.high,
      originalQuestion: original,
      amount: amount.value,
      loanText: loanText,
    );
  }

  static WhatIfIntent? _matchReduceCategorySpending(String normalized, String original) {
    final reduceWords = ['reduce', 'cut', 'spend less on', 'less on', 'lower'];
    if (!reduceWords.any(normalized.contains)) return null;

    // "on <category>" / "on my <category>" gives the clearest category
    // candidate; without it, this isn't confidently category-scoped. The
    // category may sit at the very end of the sentence ("...less on
    // food?"), so this must not require a trailing keyword/digit — only
    // letters are captured, which naturally stops before punctuation.
    final categoryMatch = RegExp(
      r'(?:on|for)\s+([a-z]+(?:\s+[a-z]+){0,2})',
    ).firstMatch(normalized);
    if (categoryMatch == null) return null;
    final categoryText = _cleanEntityCandidate(categoryMatch.group(1));
    if (categoryText == null) return null;

    final percentage = PercentageParser.parse(original);
    final strippedForAmount = PercentageParser.stripPercentage(original);
    final amount = percentage == null ? AmountParser.parse(strippedForAmount) : null;

    if (percentage == null && amount == null) {
      return WhatIfIntent(
        type: WhatIfIntentType.reduceCategorySpending,
        confidence: WhatIfConfidence.medium,
        originalQuestion: original,
        categoryText: categoryText,
        clarificationPrompt: 'By how much (₹ or %) would you like to reduce $categoryText spending?',
      );
    }

    return WhatIfIntent(
      type: WhatIfIntentType.reduceCategorySpending,
      confidence: WhatIfConfidence.high,
      originalQuestion: original,
      categoryText: categoryText,
      percentage: percentage,
      amount: amount?.value,
    );
  }

  static WhatIfIntent? _matchDecreaseExpenses(String normalized, String original) {
    if (!(normalized.contains('expense') || normalized.contains('spending') || normalized.contains('spend'))) {
      return null;
    }
    if (!(normalized.contains('reduce') ||
        normalized.contains('decrease') ||
        normalized.contains('cut') ||
        normalized.contains('less') ||
        normalized.contains('lower') ||
        normalized.contains('increase'))) {
      return null;
    }

    final percentage = PercentageParser.parse(original);
    final strippedForAmount = PercentageParser.stripPercentage(original);
    final amount = percentage == null ? AmountParser.parse(strippedForAmount) : null;

    if (percentage == null && amount == null) {
      return WhatIfIntent(
        type: WhatIfIntentType.decreaseExpenses,
        confidence: WhatIfConfidence.medium,
        originalQuestion: original,
        clarificationPrompt: 'By how much (₹ or %) would your expenses change?',
      );
    }

    if (amount != null && !amount.hadExplicitMarker && amount.value < 100) {
      return WhatIfIntent(
        type: WhatIfIntentType.decreaseExpenses,
        confidence: WhatIfConfidence.medium,
        originalQuestion: original,
        clarificationPrompt: 'By how much (₹ or %) would your expenses change?',
      );
    }

    final isIncrease = normalized.contains('increase') && !normalized.contains('decrease');
    final signedAmount = amount == null ? null : (isIncrease ? amount.value : -amount.value);
    final signedPercentage = percentage == null ? null : (isIncrease ? percentage : -percentage);

    return WhatIfIntent(
      type: WhatIfIntentType.decreaseExpenses,
      confidence: WhatIfConfidence.high,
      originalQuestion: original,
      amount: signedAmount,
      percentage: signedPercentage,
    );
  }

  static WhatIfIntent? _matchIncreaseSavings(String normalized, String original) {
    if (!normalized.contains('save') && !normalized.contains('saving')) return null;

    final amount = AmountParser.parse(original);
    if (amount == null) {
      return WhatIfIntent(
        type: WhatIfIntentType.increaseSavings,
        confidence: WhatIfConfidence.medium,
        originalQuestion: original,
        clarificationPrompt: 'How much would you like to save each month?',
      );
    }

    if (!amount.hadExplicitMarker && amount.value < 100) {
      return WhatIfIntent(
        type: WhatIfIntentType.increaseSavings,
        confidence: WhatIfConfidence.medium,
        originalQuestion: original,
        clarificationPrompt: 'How much would you like to save each month?',
      );
    }

    return WhatIfIntent(
      type: WhatIfIntentType.increaseSavings,
      confidence: WhatIfConfidence.high,
      originalQuestion: original,
      amount: amount.value,
    );
  }

  static WhatIfIntent? _matchReachEmergencyFund(String normalized, String original) {
    if (!normalized.contains('emergency fund') && !normalized.contains('emergency savings')) {
      return null;
    }

    final amount = AmountParser.parse(original);
    final hasExplicitAdditionalSavings =
        normalized.contains('save') && amount != null && amount.hadExplicitMarker;

    return WhatIfIntent(
      type: WhatIfIntentType.reachEmergencyFund,
      confidence: WhatIfConfidence.high,
      originalQuestion: original,
      amount: hasExplicitAdditionalSavings ? amount.value : null,
    );
  }

  static WhatIfIntent? _matchReachGoal(String normalized, String original) {
    final hasReachWord = normalized.contains('reach') || normalized.contains('complete');
    if (!hasReachWord) return null;

    final goalNameMatch = RegExp(
      r'(?:my|the)\s+([a-z ]+?)\s+goal',
    ).firstMatch(normalized);
    final goalText = goalNameMatch?.group(1)?.trim();

    final amount = AmountParser.parse(original);
    final hasCurrencyMarkedAmount = amount != null && amount.hadExplicitMarker;

    if (goalText == null && !hasCurrencyMarkedAmount) {
      // Neither a named goal nor a clear target amount — nothing safe to
      // calculate; let it fall through to the normal AI path rather than
      // asking an overly generic clarification question.
      return null;
    }

    return WhatIfIntent(
      type: WhatIfIntentType.reachGoal,
      confidence: WhatIfConfidence.high,
      originalQuestion: original,
      targetAmount: hasCurrencyMarkedAmount ? amount.value : null,
      categoryText: goalText, // reused as the goal-name candidate
    );
  }
}
