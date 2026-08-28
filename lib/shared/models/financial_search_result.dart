import 'package:flutter/foundation.dart';

/// PAYSENSE SEARCH — one of the result groups a query can produce.
/// Deliberately mirrors the "Transactions / Accounts / Recurring /
/// Insights / Features" grouping requested for the Financial Command
/// Center.
enum FinancialSearchResultType { transaction, wallet, recurring, loan, goal, insight, feature }

@immutable
class FinancialSearchResult {
  const FinancialSearchResult({
    required this.type,
    required this.title,
    required this.subtitle,
    this.amount,
    this.date,
    this.route,
    this.entityId,
  });

  final FinancialSearchResultType type;
  final String title;
  final String subtitle;
  final double? amount;
  final DateTime? date;

  /// An `AppRoutes` constant to navigate to when tapped, if applicable.
  final String? route;

  /// The underlying record's id (transaction/wallet/loan/goal id), for a
  /// future "open this exact record" deep link — not resolved by every
  /// route yet, kept for forward compatibility.
  final String? entityId;
}

/// A single deterministic "answer" to a query like "how much did I spend
/// this month?" — a computed figure, never sent to AI unless the
/// deterministic engine genuinely cannot answer (see PHASE L).
@immutable
class FinancialSearchAnswer {
  const FinancialSearchAnswer({required this.question, required this.answer, this.amount});

  final String question;
  final String answer;
  final double? amount;
}
