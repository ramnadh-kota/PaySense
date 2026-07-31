import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Represents a financial transaction such as income, expense, or transfer.
@immutable
class Transaction {
  /// Creates an immutable transaction.
  const Transaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.categoryId,
    required this.accountId,
    required this.transactionType,
    required this.paymentMethod,
    required this.note,
    required this.createdAt,
  });

  /// Unique identifier for the transaction.
  final String id;

  /// Display title for the transaction.
  final String title;

  /// Transaction amount.
  final double amount;

  /// Category associated with the transaction.
  final String categoryId;

  /// Account associated with the transaction.
  final String accountId;

  /// Type of transaction.
  final String transactionType;

  /// Payment method used for the transaction.
  final String paymentMethod;

  /// Optional note describing the transaction.
  final String note;

  /// Time when the transaction was created.
  final DateTime createdAt;

  /// Creates a copy of this transaction with the provided values.
  Transaction copyWith({
    String? id,
    String? title,
    double? amount,
    String? categoryId,
    String? accountId,
    String? transactionType,
    String? paymentMethod,
    String? note,
    DateTime? createdAt,
  }) {
    return Transaction(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      categoryId: categoryId ?? this.categoryId,
      accountId: accountId ?? this.accountId,
      transactionType: transactionType ?? this.transactionType,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Converts the model to a Map for persistence or transport.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'amount': amount,
      'categoryId': categoryId,
      'accountId': accountId,
      'transactionType': transactionType,
      'paymentMethod': paymentMethod,
      'note': note,
      'createdAt': _serializeDateTime(createdAt),
    };
  }

  /// Creates a model from a Map.
  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'] as String,
      title: map['title'] as String,
      amount: (map['amount'] as num).toDouble(),
      categoryId: map['categoryId'] as String,
      accountId: map['accountId'] as String,
      transactionType: map['transactionType'] as String,
      paymentMethod: map['paymentMethod'] as String,
      note: map['note'] as String,
      createdAt: _deserializeDateTime(map['createdAt']),
    );
  }

  /// Converts the model to a JSON string.
  String toJson() => jsonEncode(toMap());

  /// Creates a model from a JSON string.
  factory Transaction.fromJson(String source) {
    final decoded = jsonDecode(source) as Map<String, dynamic>;
    return Transaction.fromMap(decoded);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is Transaction &&
        other.id == id &&
        other.title == title &&
        other.amount == amount &&
        other.categoryId == categoryId &&
        other.accountId == accountId &&
        other.transactionType == transactionType &&
        other.paymentMethod == paymentMethod &&
        other.note == note &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      title,
      amount,
      categoryId,
      accountId,
      transactionType,
      paymentMethod,
      note,
      createdAt,
    );
  }

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
