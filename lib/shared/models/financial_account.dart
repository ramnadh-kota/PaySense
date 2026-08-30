import 'package:flutter/foundation.dart';

/// Phase 7A — Financial Account Type
///
/// Categorizes the financial instrument for balance classification,
/// asset vs liability treatment, and UI presentation.
enum FinancialAccountType {
  bank,
  creditCard,
  upi,
  cash,
  wallet,
  other,
}

extension FinancialAccountTypeExt on FinancialAccountType {
  String get name => toString().split('.').last;

  static FinancialAccountType fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'bank':
        return FinancialAccountType.bank;
      case 'creditcard':
      case 'credit_card':
        return FinancialAccountType.creditCard;
      case 'upi':
        return FinancialAccountType.upi;
      case 'cash':
        return FinancialAccountType.cash;
      case 'wallet':
        return FinancialAccountType.wallet;
      case 'other':
      default:
        return FinancialAccountType.other;
    }
  }
}

/// Phase 7A — Financial Account Source
///
/// Identifies the provenance of account data to distinguish manually managed
/// records from ingested feeds or future account aggregators.
enum FinancialAccountSource {
  manual,
  sms,
  csv,
  statement,
  accountAggregator,
}

extension FinancialAccountSourceExt on FinancialAccountSource {
  String get name => toString().split('.').last;

  static FinancialAccountSource fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'manual':
        return FinancialAccountSource.manual;
      case 'sms':
        return FinancialAccountSource.sms;
      case 'csv':
        return FinancialAccountSource.csv;
      case 'statement':
        return FinancialAccountSource.statement;
      case 'accountaggregator':
      case 'account_aggregator':
        return FinancialAccountSource.accountAggregator;
      default:
        return FinancialAccountSource.manual;
    }
  }
}

/// Phase 7A — Financial Account Domain Model
///
/// An immutable, local-first representation of a user's financial account.
/// Serves as the unified abstraction layer across manual wallets, imported statements,
/// and future Account Aggregator data streams.
@immutable
class FinancialAccount {
  const FinancialAccount({
    required this.id,
    required this.name,
    required this.type,
    required this.source,
    required this.balance,
    this.currency = 'INR',
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.legacyWalletId,
  });

  final String id;
  final String name;
  final FinancialAccountType type;
  final FinancialAccountSource source;
  final double balance;
  final String currency;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? legacyWalletId;

  /// Whether this account type represents a revolving debt/liability.
  bool get isLiability => type == FinancialAccountType.creditCard;

  /// Whether this account type represents an asset (liquid or stored value).
  bool get isAsset => !isLiability;

  FinancialAccount copyWith({
    String? id,
    String? name,
    FinancialAccountType? type,
    FinancialAccountSource? source,
    double? balance,
    String? currency,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? legacyWalletId,
  }) {
    return FinancialAccount(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      source: source ?? this.source,
      balance: balance ?? this.balance,
      currency: currency ?? this.currency,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      legacyWalletId: legacyWalletId ?? this.legacyWalletId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'source': source.name,
      'balance': balance,
      'currency': currency,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      if (legacyWalletId != null) 'legacyWalletId': legacyWalletId,
    };
  }

  factory FinancialAccount.fromMap(Map<dynamic, dynamic> map) {
    final id = map['id']?.toString() ?? '';
    final name = map['name']?.toString() ?? '';
    final type = FinancialAccountTypeExt.fromString(map['type']?.toString());
    final source = FinancialAccountSourceExt.fromString(map['source']?.toString());
    final balance = (map['balance'] as num?)?.toDouble() ?? 0.0;
    final currency = map['currency']?.toString() ?? 'INR';
    final isActive = map['isActive'] as bool? ?? true;

    final createdAtStr = map['createdAt']?.toString();
    final createdAt = createdAtStr != null
        ? DateTime.tryParse(createdAtStr) ?? DateTime.now()
        : DateTime.now();

    final updatedAtStr = map['updatedAt']?.toString();
    final updatedAt = updatedAtStr != null
        ? DateTime.tryParse(updatedAtStr) ?? DateTime.now()
        : DateTime.now();

    final legacyWalletId = map['legacyWalletId']?.toString();

    return FinancialAccount(
      id: id,
      name: name,
      type: type,
      source: source,
      balance: balance,
      currency: currency,
      isActive: isActive,
      createdAt: createdAt,
      updatedAt: updatedAt,
      legacyWalletId: legacyWalletId,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FinancialAccount &&
        other.id == id &&
        other.name == name &&
        other.type == type &&
        other.source == source &&
        other.balance == balance &&
        other.currency == currency &&
        other.isActive == isActive &&
        other.createdAt.isAtSameMomentAs(createdAt) &&
        other.updatedAt.isAtSameMomentAs(updatedAt) &&
        other.legacyWalletId == legacyWalletId;
  }

  @override
  int get hashCode => Object.hash(
        id,
        name,
        type,
        source,
        balance,
        currency,
        isActive,
        createdAt,
        updatedAt,
        legacyWalletId,
      );

  @override
  String toString() =>
      'FinancialAccount(id: $id, name: $name, type: ${type.name}, source: ${source.name}, balance: $balance, currency: $currency, isActive: $isActive, legacyWalletId: $legacyWalletId)';
}
