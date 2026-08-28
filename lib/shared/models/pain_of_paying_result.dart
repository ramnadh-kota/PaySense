import 'package:flutter/foundation.dart';

/// PAIN-OF-PAYING ENGINE. A deterministic AWARENESS indicator — never a
/// financial-risk prediction, never a score derived from anything the
/// engine can't point to a real number for. See
/// `PainOfPayingEngine`'s class doc for exactly how each level is reached.
enum PainOfPayingLevel { low, moderate, high, veryHigh }

/// One real, calculated comparison backing a [PainOfPayingResult] — e.g.
/// "You've spent ₹4,850 on Dining this week." Every [detail] string is
/// built from real stored data; a signal is simply omitted by
/// `PainOfPayingEngine` rather than included with a placeholder when the
/// underlying data doesn't exist.
@immutable
class PainOfPayingSignal {
  const PainOfPayingSignal({required this.label, required this.detail});

  final String label;
  final String detail;
}

@immutable
class PainOfPayingResult {
  const PainOfPayingResult({
    required this.amount,
    required this.level,
    required this.headline,
    required this.signals,
    this.suggestedAction,
  });

  final double amount;
  final PainOfPayingLevel level;

  /// e.g. "₹450 spent on Food."
  final String headline;

  /// Zero or more real, calculated comparisons. Never padded to a fixed
  /// count — a quiet purchase with nothing notable to say may have zero
  /// signals.
  final List<PainOfPayingSignal> signals;

  /// Neutral, non-shaming next-step language. Null when [level] is
  /// [PainOfPayingLevel.low] or there's nothing useful to suggest.
  final String? suggestedAction;
}
