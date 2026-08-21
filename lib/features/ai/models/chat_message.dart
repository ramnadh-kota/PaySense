import 'package:paysense/features/ai/models/affordability_outcome.dart';
import 'package:paysense/features/ai/models/tax_outcome.dart';
import 'package:paysense/features/ai/models/what_if_result.dart';

class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime createdAt;

  /// Set only on an assistant reply that followed a deterministic what-if
  /// calculation (PHASE 14) — renders the structured result card alongside
  /// the AI's explanation. Purely in-memory UI state, never persisted/
  /// exported: chat history isn't Hive-backed, so this doesn't need to
  /// round-trip through [toMap]/[fromMap].
  final WhatIfResult? whatIfResult;

  /// Set only on an assistant reply that followed a deterministic tax
  /// calculation or regime comparison (INDIA TAX PLANNER 1.0, PHASE 14) —
  /// same purely in-memory UI-state treatment as [whatIfResult].
  final TaxOutcome? taxOutcome;

  /// Set only on an assistant reply that followed a deterministic
  /// affordability calculation (FINANCIAL ACTION ENGINE 1.0, PHASE 9) —
  /// same purely in-memory UI-state treatment as [whatIfResult].
  final AffordabilityOutcome? affordabilityOutcome;

  const ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.createdAt,
    this.whatIfResult,
    this.taxOutcome,
    this.affordabilityOutcome,
  });

  ChatMessage copyWith({
    String? id,
    String? text,
    bool? isUser,
    DateTime? createdAt,
    WhatIfResult? whatIfResult,
    TaxOutcome? taxOutcome,
    AffordabilityOutcome? affordabilityOutcome,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      createdAt: createdAt ?? this.createdAt,
      whatIfResult: whatIfResult ?? this.whatIfResult,
      taxOutcome: taxOutcome ?? this.taxOutcome,
      affordabilityOutcome: affordabilityOutcome ?? this.affordabilityOutcome,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'createdAt': createdAt.toIso8601String(),
      'isUser': isUser,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    if (map.isEmpty) {
      throw ArgumentError.value(map, 'map', 'Map must not be empty');
    }

    final rawId = map['id'];
    final rawText = map['text'];
    final rawIsUser = map['isUser'];
    final rawCreatedAt = map['createdAt'];

    if (rawId == null) {
      throw ArgumentError.notNull('id');
    }
    if (rawText == null) {
      throw ArgumentError.notNull('text');
    }
    if (rawCreatedAt == null) {
      throw ArgumentError.notNull('createdAt');
    }

    final id = rawId.toString();
    final text = rawText.toString();

    final bool isUser;
    if (rawIsUser is bool) {
      isUser = rawIsUser;
    } else if (rawIsUser is int) {
      isUser = rawIsUser != 0;
    } else if (rawIsUser is String) {
      isUser = rawIsUser.toLowerCase() == 'true';
    } else {
      isUser = false;
    }

    final DateTime createdAt;
    if (rawCreatedAt is int) {
      createdAt = DateTime.fromMillisecondsSinceEpoch(rawCreatedAt);
    } else if (rawCreatedAt is String) {
      createdAt = DateTime.parse(rawCreatedAt);
    } else if (rawCreatedAt is DateTime) {
      createdAt = rawCreatedAt;
    } else {
      throw ArgumentError.value(
        rawCreatedAt,
        'createdAt',
        'Invalid createdAt value',
      );
    }

    return ChatMessage(
      id: id,
      text: text,
      isUser: isUser,
      createdAt: createdAt,
    );
  }
}
