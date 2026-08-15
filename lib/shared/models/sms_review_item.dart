import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

part 'sms_review_item.g.dart';

/// Direction of money movement implied by a parsed SMS.
enum SmsReviewDirection { debit, credit }

extension SmsReviewDirectionX on SmsReviewDirection {
  static SmsReviewDirection fromKey(String key) {
    return SmsReviewDirection.values.firstWhere(
      (d) => d.name == key,
      orElse: () => SmsReviewDirection.debit,
    );
  }
}

/// Current disposition of a medium-confidence SMS-detected transaction that
/// needed human review rather than being auto-added.
enum SmsReviewStatus { pending, accepted, ignored }

extension SmsReviewStatusX on SmsReviewStatus {
  static SmsReviewStatus fromKey(String key) {
    return SmsReviewStatus.values.firstWhere(
      (s) => s.name == key,
      orElse: () => SmsReviewStatus.pending,
    );
  }
}

/// A medium-confidence transaction detected from a bank/UPI SMS that could
/// not be auto-added — either the parser wasn't confident enough, or the
/// wallet to attribute it to was ambiguous. Persisted so the user can
/// accept or ignore it later, and so the SAME underlying SMS is never
/// surfaced for review twice (see [id], which is the SMS's deterministic
/// fingerprint).
///
/// Deliberately does NOT retain the raw SMS body — only the minimum fields
/// `SmsTransactionParser` extracted from it, per the requirement to discard
/// raw SMS content once it has been parsed. [direction]/[status] are stored
/// as plain strings (matching every other enum-like field in this codebase,
/// e.g. `AppNotification.type`) rather than as Hive-typed enums, so no
/// separate enum adapter needs registering.
@immutable
@HiveType(typeId: 10)
class SmsReviewItem {
  const SmsReviewItem({
    required this.id,
    required this.amount,
    required this.directionKey,
    required this.sender,
    required this.timestamp,
    required this.confidence,
    required this.isLikelyTransfer,
    required this.statusKey,
    required this.createdAt,
    this.merchant,
    this.suggestedWalletId,
  });

  factory SmsReviewItem.create({
    required String id,
    required double amount,
    required SmsReviewDirection direction,
    required String sender,
    required DateTime timestamp,
    required double confidence,
    bool isLikelyTransfer = false,
    String? merchant,
    String? suggestedWalletId,
  }) {
    return SmsReviewItem(
      id: id,
      amount: amount,
      directionKey: direction.name,
      sender: sender,
      timestamp: timestamp,
      confidence: confidence,
      isLikelyTransfer: isLikelyTransfer,
      statusKey: SmsReviewStatus.pending.name,
      createdAt: DateTime.now(),
      merchant: merchant,
      suggestedWalletId: suggestedWalletId,
    );
  }

  /// The SMS's deterministic fingerprint — see
  /// `SmsTransactionParser.buildFingerprint`. Doubles as the Hive key so a
  /// re-delivered/re-processed copy of the same SMS can never create a
  /// second review item.
  @HiveField(0)
  final String id;

  @HiveField(1)
  final double amount;

  @HiveField(2)
  final String directionKey;

  @HiveField(3)
  final String sender;

  @HiveField(4)
  final DateTime timestamp;

  @HiveField(5)
  final double confidence;

  @HiveField(6)
  final bool isLikelyTransfer;

  @HiveField(7)
  final String statusKey;

  @HiveField(8)
  final DateTime createdAt;

  @HiveField(9)
  final String? merchant;

  /// The single wallet this SMS most likely belongs to, when the wallet
  /// matcher found exactly one plausible (but not confident-enough)
  /// candidate. Null when no candidate could be identified at all. Never
  /// auto-applied — the user still explicitly confirms the wallet.
  @HiveField(10)
  final String? suggestedWalletId;

  SmsReviewDirection get direction => SmsReviewDirectionX.fromKey(directionKey);

  SmsReviewStatus get status => SmsReviewStatusX.fromKey(statusKey);

  SmsReviewItem copyWith({
    SmsReviewStatus? status,
    String? suggestedWalletId,
  }) {
    return SmsReviewItem(
      id: id,
      amount: amount,
      directionKey: directionKey,
      sender: sender,
      timestamp: timestamp,
      confidence: confidence,
      isLikelyTransfer: isLikelyTransfer,
      statusKey: (status ?? this.status).name,
      createdAt: createdAt,
      merchant: merchant,
      suggestedWalletId: suggestedWalletId ?? this.suggestedWalletId,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'amount': amount,
      'direction': directionKey,
      'sender': sender,
      'timestamp': timestamp.toIso8601String(),
      'confidence': confidence,
      'isLikelyTransfer': isLikelyTransfer,
      'status': statusKey,
      'createdAt': createdAt.toIso8601String(),
      'merchant': merchant,
      'suggestedWalletId': suggestedWalletId,
    };
  }

  factory SmsReviewItem.fromMap(Map<String, dynamic> map) {
    return SmsReviewItem(
      id: map['id'] as String,
      amount: (map['amount'] as num).toDouble(),
      directionKey: map['direction'] as String,
      sender: map['sender'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      confidence: (map['confidence'] as num).toDouble(),
      isLikelyTransfer: map['isLikelyTransfer'] as bool,
      statusKey: map['status'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      merchant: map['merchant'] as String?,
      suggestedWalletId: map['suggestedWalletId'] as String?,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory SmsReviewItem.fromJson(String source) {
    final decoded = jsonDecode(source) as Map<String, dynamic>;
    return SmsReviewItem.fromMap(decoded);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is SmsReviewItem &&
        other.id == id &&
        other.amount == amount &&
        other.directionKey == directionKey &&
        other.sender == sender &&
        other.timestamp == timestamp &&
        other.confidence == confidence &&
        other.isLikelyTransfer == isLikelyTransfer &&
        other.statusKey == statusKey &&
        other.createdAt == createdAt &&
        other.merchant == merchant &&
        other.suggestedWalletId == suggestedWalletId;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      amount,
      directionKey,
      sender,
      timestamp,
      confidence,
      isLikelyTransfer,
      statusKey,
      Object.hash(createdAt, merchant, suggestedWalletId),
    );
  }
}
