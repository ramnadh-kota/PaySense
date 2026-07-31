import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Represents a monthly budget for a category.
@immutable
class Budget {
  /// Creates an immutable budget.
  const Budget({
    required this.id,
    required this.categoryId,
    required this.monthlyLimit,
    required this.spent,
    required this.month,
  });

  /// Unique identifier for the budget.
  final String id;

  /// Category associated with the budget.
  final String categoryId;

  /// Monthly budget limit.
  final double monthlyLimit;

  /// Amount already spent this month.
  final double spent;

  /// Budget month in YYYY-MM format.
  final String month;

  /// Creates a copy of this budget with the provided values.
  Budget copyWith({
    String? id,
    String? categoryId,
    double? monthlyLimit,
    double? spent,
    String? month,
  }) {
    return Budget(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      monthlyLimit: monthlyLimit ?? this.monthlyLimit,
      spent: spent ?? this.spent,
      month: month ?? this.month,
    );
  }

  /// Converts the model to a Map for persistence or transport.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'categoryId': categoryId,
      'monthlyLimit': monthlyLimit,
      'spent': spent,
      'month': month,
    };
  }

  /// Creates a model from a Map.
  factory Budget.fromMap(Map<String, dynamic> map) {
    return Budget(
      id: map['id'] as String,
      categoryId: map['categoryId'] as String,
      monthlyLimit: (map['monthlyLimit'] as num).toDouble(),
      spent: (map['spent'] as num).toDouble(),
      month: map['month'] as String,
    );
  }

  /// Converts the model to a JSON string.
  String toJson() => jsonEncode(toMap());

  /// Creates a model from a JSON string.
  factory Budget.fromJson(String source) {
    final decoded = jsonDecode(source) as Map<String, dynamic>;
    return Budget.fromMap(decoded);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is Budget &&
        other.id == id &&
        other.categoryId == categoryId &&
        other.monthlyLimit == monthlyLimit &&
        other.spent == spent &&
        other.month == month;
  }

  @override
  int get hashCode => Object.hash(id, categoryId, monthlyLimit, spent, month);
}
