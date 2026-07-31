import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Represents a credit card with its limit and due date.
@immutable
class CreditCard {
  /// Creates an immutable credit card.
  const CreditCard({
    required this.id,
    required this.bankName,
    required this.cardNumber,
    required this.totalLimit,
    required this.availableLimit,
    required this.dueDate,
  });

  /// Unique identifier for the card.
  final String id;

  /// Name of the issuing bank.
  final String bankName;

  /// Card number or masked identifier.
  final String cardNumber;

  /// Total credit limit.
  final double totalLimit;

  /// Remaining available credit.
  final double availableLimit;

  /// Due date for the card statement.
  final DateTime dueDate;

  /// Creates a copy of this card with the provided values.
  CreditCard copyWith({
    String? id,
    String? bankName,
    String? cardNumber,
    double? totalLimit,
    double? availableLimit,
    DateTime? dueDate,
  }) {
    return CreditCard(
      id: id ?? this.id,
      bankName: bankName ?? this.bankName,
      cardNumber: cardNumber ?? this.cardNumber,
      totalLimit: totalLimit ?? this.totalLimit,
      availableLimit: availableLimit ?? this.availableLimit,
      dueDate: dueDate ?? this.dueDate,
    );
  }

  /// Converts the model to a Map for persistence or transport.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'bankName': bankName,
      'cardNumber': cardNumber,
      'totalLimit': totalLimit,
      'availableLimit': availableLimit,
      'dueDate': _serializeDateTime(dueDate),
    };
  }

  /// Creates a model from a Map.
  factory CreditCard.fromMap(Map<String, dynamic> map) {
    return CreditCard(
      id: map['id'] as String,
      bankName: map['bankName'] as String,
      cardNumber: map['cardNumber'] as String,
      totalLimit: (map['totalLimit'] as num).toDouble(),
      availableLimit: (map['availableLimit'] as num).toDouble(),
      dueDate: _deserializeDateTime(map['dueDate']),
    );
  }

  /// Converts the model to a JSON string.
  String toJson() => jsonEncode(toMap());

  /// Creates a model from a JSON string.
  factory CreditCard.fromJson(String source) {
    final decoded = jsonDecode(source) as Map<String, dynamic>;
    return CreditCard.fromMap(decoded);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is CreditCard &&
        other.id == id &&
        other.bankName == bankName &&
        other.cardNumber == cardNumber &&
        other.totalLimit == totalLimit &&
        other.availableLimit == availableLimit &&
        other.dueDate == dueDate;
  }

  @override
  int get hashCode => Object.hash(id, bankName, cardNumber, totalLimit, availableLimit, dueDate);

  static String _serializeDateTime(DateTime value) => value.toUtc().toIso8601String();

  static DateTime _deserializeDateTime(Object? value) {
    if (value is String) {
      return DateTime.parse(value);
    }
    if (value is DateTime) {
      return value;
    }
    throw FormatException('Invalid DateTime value: $value');
  }
}
