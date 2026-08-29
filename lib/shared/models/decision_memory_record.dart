import 'package:flutter/foundation.dart';

import '../utils/affordability_calculator.dart';
import '../utils/allowance_calculator.dart';
import '../utils/spending_decision_calculator.dart';

/// User choice when coached on a prospective purchase.
enum DecisionUserAction {
  proceeded,
  cancelled,
}

extension DecisionUserActionExt on DecisionUserAction {
  String get name => toString().split('.').last;

  static DecisionUserAction fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'proceeded':
        return DecisionUserAction.proceeded;
      case 'cancelled':
      default:
        return DecisionUserAction.cancelled;
    }
  }
}

/// Phase 6E — Decision Memory Record
///
/// A minimal, immutable record of a single spending decision evaluated through
/// PaySense Decision Coach. Stored locally to allow deterministic pattern learning.
@immutable
class DecisionMemoryRecord {
  const DecisionMemoryRecord({
    required this.id,
    required this.timestamp,
    required this.categoryId,
    required this.amount,
    required this.recommendationTier,
    required this.userAction,
    required this.verdictLine,
    this.allowanceState,
    this.affordabilityStatus,
    this.itemDescription,
  });

  final String id;
  final DateTime timestamp;
  final String categoryId;
  final double amount;
  final SpendingRecommendationTier recommendationTier;
  final DecisionUserAction userAction;
  final String verdictLine;
  final AllowanceState? allowanceState;
  final AffordabilityStatus? affordabilityStatus;
  final String? itemDescription;

  bool get wasProceeded => userAction == DecisionUserAction.proceeded;
  bool get wasCancelled => userAction == DecisionUserAction.cancelled;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'categoryId': categoryId,
      'amount': amount,
      'recommendationTier': recommendationTier.name,
      'userAction': userAction.name,
      'verdictLine': verdictLine,
      'allowanceState': allowanceState?.name,
      'affordabilityStatus': affordabilityStatus?.name,
      if (itemDescription != null) 'itemDescription': itemDescription,
    };
  }

  factory DecisionMemoryRecord.fromMap(Map<dynamic, dynamic> map) {
    final id = map['id']?.toString() ?? '';
    final timestampStr = map['timestamp']?.toString();
    final timestamp = timestampStr != null
        ? DateTime.tryParse(timestampStr) ?? DateTime.now()
        : DateTime.now();
    final categoryId = map['categoryId']?.toString() ?? 'uncategorized';
    final amount = (map['amount'] as num?)?.toDouble() ?? 0.0;

    final tierStr = map['recommendationTier']?.toString();
    final recommendationTier = _parseTier(tierStr);

    final actionStr = map['userAction']?.toString();
    final userAction = DecisionUserActionExt.fromString(actionStr);

    final verdictLine = map['verdictLine']?.toString() ?? '';

    final allowanceStr = map['allowanceState']?.toString();
    final allowanceState = _parseAllowanceState(allowanceStr);

    final affordabilityStr = map['affordabilityStatus']?.toString();
    final affordabilityStatus = _parseAffordabilityStatus(affordabilityStr);

    final itemDescription = map['itemDescription']?.toString();

    return DecisionMemoryRecord(
      id: id,
      timestamp: timestamp,
      categoryId: categoryId,
      amount: amount,
      recommendationTier: recommendationTier,
      userAction: userAction,
      verdictLine: verdictLine,
      allowanceState: allowanceState,
      affordabilityStatus: affordabilityStatus,
      itemDescription: itemDescription,
    );
  }

  static SpendingRecommendationTier _parseTier(String? tierStr) {
    switch (tierStr?.toLowerCase()) {
      case 'spend':
        return SpendingRecommendationTier.spend;
      case 'thinkagain':
        return SpendingRecommendationTier.thinkAgain;
      case 'avoid':
        return SpendingRecommendationTier.avoid;
      default:
        return SpendingRecommendationTier.spend;
    }
  }

  static AllowanceState? _parseAllowanceState(String? str) {
    if (str == null) return null;
    switch (str.toLowerCase()) {
      case 'comfortable':
        return AllowanceState.comfortable;
      case 'watchful':
        return AllowanceState.watchful;
      case 'tight':
        return AllowanceState.tight;
      case 'overallowance':
        return AllowanceState.overAllowance;
      default:
        return null;
    }
  }

  static AffordabilityStatus? _parseAffordabilityStatus(String? str) {
    if (str == null) return null;
    switch (str.toLowerCase()) {
      case 'comfortable':
        return AffordabilityStatus.comfortable;
      case 'possible':
        return AffordabilityStatus.possible;
      case 'risky':
        return AffordabilityStatus.risky;
      case 'notrecommended':
        return AffordabilityStatus.notRecommended;
      case 'insufficientdata':
        return AffordabilityStatus.insufficientData;
      default:
        return null;
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DecisionMemoryRecord &&
        other.id == id &&
        other.timestamp.isAtSameMomentAs(timestamp) &&
        other.categoryId == categoryId &&
        other.amount == amount &&
        other.recommendationTier == recommendationTier &&
        other.userAction == userAction &&
        other.verdictLine == verdictLine &&
        other.allowanceState == allowanceState &&
        other.affordabilityStatus == affordabilityStatus &&
        other.itemDescription == itemDescription;
  }

  @override
  int get hashCode => Object.hash(
        id,
        timestamp,
        categoryId,
        amount,
        recommendationTier,
        userAction,
        verdictLine,
        allowanceState,
        affordabilityStatus,
        itemDescription,
      );
}
