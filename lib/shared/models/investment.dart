import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Represents an investment holding.
@immutable
class Investment {
  /// Creates an immutable investment.
  const Investment({
    required this.id,
    required this.name,
    required this.investmentType,
    required this.investedAmount,
    required this.currentValue,
  });

  /// Unique identifier for the investment.
  final String id;

  /// Name of the investment.
  final String name;

  /// Type of investment.
  final String investmentType;

  /// Amount originally invested.
  final double investedAmount;

  /// Current value of the investment.
  final double currentValue;

  /// Creates a copy of this investment with the provided values.
  Investment copyWith({
    String? id,
    String? name,
    String? investmentType,
    double? investedAmount,
    double? currentValue,
  }) {
    return Investment(
      id: id ?? this.id,
      name: name ?? this.name,
      investmentType: investmentType ?? this.investmentType,
      investedAmount: investedAmount ?? this.investedAmount,
      currentValue: currentValue ?? this.currentValue,
    );
  }

  /// Converts the model to a Map for persistence or transport.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'investmentType': investmentType,
      'investedAmount': investedAmount,
      'currentValue': currentValue,
    };
  }

  /// Creates a model from a Map.
  factory Investment.fromMap(Map<String, dynamic> map) {
    return Investment(
      id: map['id'] as String,
      name: map['name'] as String,
      investmentType: map['investmentType'] as String,
      investedAmount: (map['investedAmount'] as num).toDouble(),
      currentValue: (map['currentValue'] as num).toDouble(),
    );
  }

  /// Converts the model to a JSON string.
  String toJson() => jsonEncode(toMap());

  /// Creates a model from a JSON string.
  factory Investment.fromJson(String source) {
    final decoded = jsonDecode(source) as Map<String, dynamic>;
    return Investment.fromMap(decoded);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is Investment &&
        other.id == id &&
        other.name == name &&
        other.investmentType == investmentType &&
        other.investedAmount == investedAmount &&
        other.currentValue == currentValue;
  }

  @override
  int get hashCode => Object.hash(id, name, investmentType, investedAmount, currentValue);
}
