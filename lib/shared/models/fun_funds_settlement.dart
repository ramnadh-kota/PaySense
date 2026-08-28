import 'package:flutter/foundation.dart';

/// Marks ONE debt — one participant's equal-split share of ONE
/// [FunFundsExpense] — as settled. The debt itself is never stored (it's
/// derived from the expense's own split, via GroupExpenseCalculator); this
/// record's mere EXISTENCE for a given (expenseId, debtorName) pair is
/// what "Settled" means — its absence means "Pending". PaySense never
/// transfers money for this — see `kSettlementTrackingOnlyDisclaimer`.
@immutable
class FunFundsSettlement {
  const FunFundsSettlement({
    required this.id,
    required this.groupId,
    required this.expenseId,
    required this.debtorName,
    required this.settledAt,
  });

  final String id;
  final String groupId;
  final String expenseId;
  final String debtorName;
  final DateTime settledAt;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'groupId': groupId,
      'expenseId': expenseId,
      'debtorName': debtorName,
      'settledAt': settledAt.toIso8601String(),
    };
  }

  factory FunFundsSettlement.fromMap(Map<String, dynamic> map) {
    return FunFundsSettlement(
      id: map['id'] as String,
      groupId: map['groupId'] as String,
      expenseId: map['expenseId'] as String,
      debtorName: map['debtorName'] as String,
      settledAt: DateTime.parse(map['settledAt'] as String),
    );
  }
}

/// Shown wherever settlement status is displayed — see PHASE 6's explicit
/// requirement that this never reads as if a real payment occurred.
const String kSettlementTrackingOnlyDisclaimer =
    'Settlement tracking only — PaySense does not transfer money.';
