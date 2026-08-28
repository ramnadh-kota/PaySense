import 'package:flutter/foundation.dart';

/// One shared expense within a [FunFundsGroup] — who paid, the total, and
/// who it's split across. Split SHARES are never stored here; they're
/// always computed on demand by `GroupExpenseCalculator.equalSplit` from
/// [totalAmount]/[participantNames].length, so there is exactly one place
/// that can get split-rounding wrong, and it's covered by its own test
/// suite.
@immutable
class FunFundsExpense {
  const FunFundsExpense({
    required this.id,
    required this.groupId,
    required this.description,
    required this.totalAmount,
    required this.payerName,
    required this.participantNames,
    required this.createdAt,
  });

  final String id;
  final String groupId;
  final String description;
  final double totalAmount;

  /// Must be one of the owning [FunFundsGroup.memberNames].
  final String payerName;

  /// Who the expense is split across — EQUAL split only today (see
  /// GroupExpenseCalculator). Includes [payerName] when they also
  /// consumed a share (the common case); a payer covering others without
  /// taking a share themselves simply omits their own name here.
  final List<String> participantNames;
  final DateTime createdAt;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'groupId': groupId,
      'description': description,
      'totalAmount': totalAmount,
      'payerName': payerName,
      'participantNames': participantNames,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory FunFundsExpense.fromMap(Map<String, dynamic> map) {
    return FunFundsExpense(
      id: map['id'] as String,
      groupId: map['groupId'] as String,
      description: map['description'] as String,
      totalAmount: (map['totalAmount'] as num).toDouble(),
      payerName: map['payerName'] as String,
      participantNames: (map['participantNames'] as List).cast<String>(),
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
}
