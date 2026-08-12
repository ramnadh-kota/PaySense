import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

part 'account.g.dart';

/// A local login account. Passwords are never stored in plaintext — only a
/// salted hash ([passwordHash]) is persisted.
@immutable
@HiveType(typeId: 8)
class Account {
  const Account({
    required this.id,
    required this.email,
    required this.fullName,
    required this.passwordHash,
    required this.passwordSalt,
    required this.createdAt,
    required this.updatedAt,
  });

  @HiveField(0)
  final String id;

  /// Normalized (lowercased, trimmed) email — used as the lookup key.
  @HiveField(1)
  final String email;

  @HiveField(2)
  final String fullName;

  @HiveField(3)
  final String passwordHash;

  @HiveField(4)
  final String passwordSalt;

  @HiveField(5)
  final DateTime createdAt;

  @HiveField(6)
  final DateTime updatedAt;

  Account copyWith({
    String? id,
    String? email,
    String? fullName,
    String? passwordHash,
    String? passwordSalt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Account(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      passwordHash: passwordHash ?? this.passwordHash,
      passwordSalt: passwordSalt ?? this.passwordSalt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'email': email,
      'fullName': fullName,
      'passwordHash': passwordHash,
      'passwordSalt': passwordSalt,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Account.fromMap(Map<String, dynamic> map) {
    return Account(
      id: map['id'] as String,
      email: map['email'] as String,
      fullName: map['fullName'] as String,
      passwordHash: map['passwordHash'] as String,
      passwordSalt: map['passwordSalt'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory Account.fromJson(String source) {
    final decoded = jsonDecode(source) as Map<String, dynamic>;
    return Account.fromMap(decoded);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is Account &&
        other.id == id &&
        other.email == email &&
        other.fullName == fullName &&
        other.passwordHash == passwordHash &&
        other.passwordSalt == passwordSalt &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      email,
      fullName,
      passwordHash,
      passwordSalt,
      createdAt,
      updatedAt,
    );
  }
}
