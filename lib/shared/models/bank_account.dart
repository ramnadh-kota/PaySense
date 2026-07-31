import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Represents a bank account with its balance and type.
@immutable
class BankAccount {
  /// Creates an immutable bank account.
  const BankAccount({
    required this.id,
    required this.bankName,
    required this.accountNumber,
    required this.balance,
    required this.accountType,
    required this.updatedAt,
  });

  /// Unique identifier for the account.
  final String id;

  /// Name of the bank.
  final String bankName;

  /// Account number or masked identifier.
  final String accountNumber;

  /// Current balance of the account.
  final double balance;

  /// Type of the account.
  final String accountType;

  /// Last time the account was updated.
  final DateTime updatedAt;

  /// Creates a copy of this account with the provided values.
  BankAccount copyWith({
    String? id,
    String? bankName,
    String? accountNumber,
    double? balance,
    String? accountType,
    DateTime? updatedAt,
  }) {
    return BankAccount(
      id: id ?? this.id,
      bankName: bankName ?? this.bankName,
      accountNumber: accountNumber ?? this.accountNumber,
      balance: balance ?? this.balance,
      accountType: accountType ?? this.accountType,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Converts the model to a Map for persistence or transport.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'bankName': bankName,
      'accountNumber': accountNumber,
      'balance': balance,
      'accountType': accountType,
      'updatedAt': _serializeDateTime(updatedAt),
    };
  }

  /// Creates a model from a Map.
  factory BankAccount.fromMap(Map<String, dynamic> map) {
    return BankAccount(
      id: map['id'] as String,
      bankName: map['bankName'] as String,
      accountNumber: map['accountNumber'] as String,
      balance: (map['balance'] as num).toDouble(),
      accountType: map['accountType'] as String,
      updatedAt: _deserializeDateTime(map['updatedAt']),
    );
  }

  /// Converts the model to a JSON string.
  String toJson() => jsonEncode(toMap());

  /// Creates a model from a JSON string.
  factory BankAccount.fromJson(String source) {
    final decoded = jsonDecode(source) as Map<String, dynamic>;
    return BankAccount.fromMap(decoded);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is BankAccount &&
        other.id == id &&
        other.bankName == bankName &&
        other.accountNumber == accountNumber &&
        other.balance == balance &&
        other.accountType == accountType &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hash(id, bankName, accountNumber, balance, accountType, updatedAt);

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
