import 'package:flutter/foundation.dart';

import 'what_if_intent_parser.dart' show AmountParser, ParsedAmount;

/// INDIA TAX PLANNER 1.0 — PHASE 10/11 deterministic tax intent detection.
/// A sibling to [WhatIfIntentParser], not a merge into it: tax questions
/// ("how much tax will I pay?", "compare old and new regime") don't need
/// (and mostly don't use) the "what if"/"when will I" hypothetical-trigger
/// phrasing that gates the general what-if pipeline, and a tax scenario's
/// result shape (a full regime breakdown) is genuinely different from a
/// [WhatIfResult]'s single before/after figure — keeping them separate
/// avoids distorting either model to fit the other.
///
/// Same core principles as [WhatIfIntentParser]: pure text parsing, no
/// repository access, never invents an amount multiplier, and a definitional
/// "what is a deduction?" falls through to the normal AI path rather than
/// being treated as an actionable calculation request.
enum TaxIntentType {
  /// "How much tax will I pay?" / "How much tax do I owe?"
  estimate,

  /// "How much tax should I keep aside?" — PHASE 9's monthly provision.
  monthlyProvision,

  /// "Compare old and new regime."
  compareRegimes,

  /// "What if my salary becomes ₹15 lakh?"
  whatIfSalary,

  /// "What if I invest ₹1.5 lakh under 80C?"
  whatIf80C,

  /// "What if I claim ₹50,000 under 80D?"
  whatIf80D,

  /// "What if I pay ₹2 lakh home-loan interest?"
  whatIfHomeLoanInterest,

  none,
}

/// Which regime(s) a direct estimate question asked for, when stated
/// explicitly — null means the question didn't say, which the orchestrator
/// treats as PHASE 12's progressive-clarification case.
enum TaxIntentRegimeChoice { old, newRegime, both }

@immutable
class TaxIntent {
  const TaxIntent({
    required this.type,
    required this.originalQuestion,
    this.amount,
    this.regimeChoice,
  });

  const TaxIntent.none(this.originalQuestion)
    : type = TaxIntentType.none,
      amount = null,
      regimeChoice = null;

  final TaxIntentType type;
  final String originalQuestion;
  final double? amount;
  final TaxIntentRegimeChoice? regimeChoice;

  bool get isActionable => type != TaxIntentType.none;
}

class TaxIntentParser {
  TaxIntentParser._();

  /// Trigger words for the GENERIC branches only (estimate/compare/
  /// monthly-provision) — the specific-scenario branches (80C/80D/home-loan
  /// interest/salary-change) each carry their own narrow, self-contained
  /// trigger conditions and are checked unconditionally, without this gate
  /// (e.g. "What if my salary becomes ₹15 lakh?" contains no generic tax
  /// keyword at all, but is still unambiguously a tax scenario).
  static final List<String> _taxDomainKeywords = [
    'tax', 'taxes', 'income tax', 'itr', 'tds', '80c', '80d', 'regime', 'deduction',
  ];

  static final List<String> _actionablePhrases = [
    'how much', 'compare', 'what if', 'keep aside', 'set aside', 'becomes',
    'invest', 'claim', 'owe', 'pay', 'liability',
  ];

  static TaxIntent parse(String question) {
    final normalized = question.toLowerCase().trim();

    final specific = _matchWhatIf80C(normalized, question) ??
        _matchWhatIf80D(normalized, question) ??
        _matchWhatIfHomeLoanInterest(normalized, question) ??
        _matchWhatIfSalary(normalized, question);
    if (specific != null) return specific;

    if (!_taxDomainKeywords.any(normalized.contains)) {
      return TaxIntent.none(question);
    }
    // A bare "what is ...tax..." definitional question (e.g. "What is a
    // tax deduction?") must fall through to the normal AI explanation
    // path, never be treated as a calculation request.
    if (normalized.contains('what is') && !_actionablePhrases.any(normalized.contains)) {
      return TaxIntent.none(question);
    }

    return _matchCompareRegimes(normalized, question) ??
        _matchMonthlyProvision(normalized, question) ??
        _matchEstimate(normalized, question) ??
        TaxIntent.none(question);
  }

  static ParsedAmount? _amount(String original) => AmountParser.parse(original);

  /// Removes a "80c"/"80 c"/"section 80c" style token (case-insensitive)
  /// before amount parsing — otherwise the bare digits inside the section
  /// number itself ("80" from "80C") would be mistaken for the amount on a
  /// question that never actually stated one (e.g. "What if I invest under
  /// 80C?").
  static String _stripSectionToken(String text, String digits) {
    return text.replaceAll(RegExp('section\\s*$digits|$digits', caseSensitive: false), ' ');
  }

  static TaxIntent? _matchWhatIf80C(String normalized, String original) {
    if (!normalized.contains('80c') && !normalized.contains('section 80 c')) return null;
    final amount = _amount(_stripSectionToken(original, '80c'));
    return TaxIntent(
      type: TaxIntentType.whatIf80C,
      originalQuestion: original,
      amount: amount?.value,
    );
  }

  static TaxIntent? _matchWhatIf80D(String normalized, String original) {
    if (!normalized.contains('80d') && !normalized.contains('section 80 d')) return null;
    final amount = _amount(_stripSectionToken(original, '80d'));
    return TaxIntent(
      type: TaxIntentType.whatIf80D,
      originalQuestion: original,
      amount: amount?.value,
    );
  }

  static TaxIntent? _matchWhatIfHomeLoanInterest(String normalized, String original) {
    if (!(normalized.contains('home loan interest') ||
        normalized.contains('home-loan interest') ||
        normalized.contains('housing loan interest'))) {
      return null;
    }
    final amount = _amount(original);
    return TaxIntent(
      type: TaxIntentType.whatIfHomeLoanInterest,
      originalQuestion: original,
      amount: amount?.value,
    );
  }

  static TaxIntent? _matchWhatIfSalary(String normalized, String original) {
    final hasSalaryWord = normalized.contains('salary') || normalized.contains('income becomes') ||
        normalized.contains('i earn');
    if (!hasSalaryWord) return null;
    final hasChangePhrase = normalized.contains('becomes') ||
        normalized.contains('increases to') ||
        normalized.contains('goes up to') ||
        normalized.contains('what if') ||
        normalized.contains('is ₹') ||
        normalized.contains('is rs');
    if (!hasChangePhrase) return null;

    final amount = _amount(original);
    return TaxIntent(
      type: TaxIntentType.whatIfSalary,
      originalQuestion: original,
      amount: amount?.value,
    );
  }

  static TaxIntent? _matchCompareRegimes(String normalized, String original) {
    final wantsCompare = normalized.contains('compare') ||
        (normalized.contains('old') && normalized.contains('new') && normalized.contains('regime')) ||
        normalized.contains('both regime');
    if (!wantsCompare) return null;
    return TaxIntent(type: TaxIntentType.compareRegimes, originalQuestion: original);
  }

  static TaxIntent? _matchMonthlyProvision(String normalized, String original) {
    final wantsProvision = normalized.contains('keep aside') ||
        normalized.contains('set aside') ||
        normalized.contains('save for tax') ||
        normalized.contains('save every month') && normalized.contains('tax') ||
        normalized.contains('monthly tax');
    if (!wantsProvision) return null;
    return TaxIntent(type: TaxIntentType.monthlyProvision, originalQuestion: original);
  }

  static TaxIntent? _matchEstimate(String normalized, String original) {
    final wantsEstimate = normalized.contains('how much tax') ||
        normalized.contains('tax will i pay') ||
        normalized.contains('tax do i owe') ||
        normalized.contains('tax i owe') ||
        normalized.contains('my tax liability') ||
        normalized.contains('estimate my tax') ||
        (normalized.contains('tax') && normalized.contains('liability'));
    if (!wantsEstimate) return null;

    TaxIntentRegimeChoice? regimeChoice;
    if (normalized.contains('both')) {
      regimeChoice = TaxIntentRegimeChoice.both;
    } else if (normalized.contains('new regime')) {
      regimeChoice = TaxIntentRegimeChoice.newRegime;
    } else if (normalized.contains('old regime')) {
      regimeChoice = TaxIntentRegimeChoice.old;
    }

    return TaxIntent(
      type: TaxIntentType.estimate,
      originalQuestion: original,
      regimeChoice: regimeChoice,
    );
  }
}
