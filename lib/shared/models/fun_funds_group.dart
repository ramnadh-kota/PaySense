import 'package:flutter/foundation.dart';

/// FUN FUNDS — FRIENDS/GROUP EXPENSES. A group of people who split shared
/// expenses (a trip, a flat, an outing). Deliberately a plain Dart class
/// with `toMap()`/`fromMap()` — mirrors
/// `AccountAggregatorConnectionRepository`'s established pattern for new
/// structured data (untyped Hive box, JSON-shaped map, no new
/// `@HiveType`/`TypeAdapter` needed) rather than introducing a 13th
/// `@HiveType` typeId.
@immutable
class FunFundsGroup {
  const FunFundsGroup({
    required this.id,
    required this.name,
    required this.memberNames,
    required this.createdAt,
  });

  final String id;
  final String name;

  /// Display names only — Fun Funds groups are informal, offline splitting
  /// between people who may not be PaySense users themselves. Never a
  /// phone number/email/account id (no contact-book integration exists).
  final List<String> memberNames;
  final DateTime createdAt;

  FunFundsGroup copyWith({String? name, List<String>? memberNames}) {
    return FunFundsGroup(
      id: id,
      name: name ?? this.name,
      memberNames: memberNames ?? this.memberNames,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'memberNames': memberNames,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory FunFundsGroup.fromMap(Map<String, dynamic> map) {
    return FunFundsGroup(
      id: map['id'] as String,
      name: map['name'] as String,
      memberNames: (map['memberNames'] as List).cast<String>(),
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
}
