import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

part 'user_profile.g.dart';

/// Represents the user's profile, collected during onboarding and editable
/// afterwards. Only [fullName] is required; everything else is optional and
/// defaults to an empty/zero value when not provided.
@immutable
@HiveType(typeId: 0)
class UserProfile {
  const UserProfile({
    required this.id,
    required this.fullName,
    this.email = '',
    this.phone = '',
    this.dateOfBirth,
    this.gender = '',
    this.occupation = '',
    this.monthlyIncome = 0.0,
    this.currency = 'INR',
    this.country = 'India',
    this.monthlyEmi = 0.0,
    this.savingsGoal = 0.0,
    required this.createdAt,
    required this.updatedAt,
  });

  @HiveField(0)
  final String id;

  @HiveField(1)
  final String fullName;

  @HiveField(2)
  final String email;

  @HiveField(3)
  final String phone;

  @HiveField(4)
  final DateTime? dateOfBirth;

  @HiveField(5)
  final String gender;

  @HiveField(6)
  final String occupation;

  @HiveField(7)
  final double monthlyIncome;

  @HiveField(8)
  final String currency;

  @HiveField(9)
  final String country;

  @HiveField(10)
  final double monthlyEmi;

  @HiveField(11)
  final double savingsGoal;

  @HiveField(12)
  final DateTime createdAt;

  @HiveField(13)
  final DateTime updatedAt;

  UserProfile copyWith({
    String? id,
    String? fullName,
    String? email,
    String? phone,
    DateTime? dateOfBirth,
    String? gender,
    String? occupation,
    double? monthlyIncome,
    String? currency,
    String? country,
    double? monthlyEmi,
    double? savingsGoal,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      occupation: occupation ?? this.occupation,
      monthlyIncome: monthlyIncome ?? this.monthlyIncome,
      currency: currency ?? this.currency,
      country: country ?? this.country,
      monthlyEmi: monthlyEmi ?? this.monthlyEmi,
      savingsGoal: savingsGoal ?? this.savingsGoal,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'dateOfBirth': dateOfBirth?.toIso8601String(),
      'gender': gender,
      'occupation': occupation,
      'monthlyIncome': monthlyIncome,
      'currency': currency,
      'country': country,
      'monthlyEmi': monthlyEmi,
      'savingsGoal': savingsGoal,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] as String,
      fullName: map['fullName'] as String,
      email: map['email'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      dateOfBirth: map['dateOfBirth'] == null
          ? null
          : DateTime.parse(map['dateOfBirth'] as String),
      gender: map['gender'] as String? ?? '',
      occupation: map['occupation'] as String? ?? '',
      monthlyIncome: (map['monthlyIncome'] as num?)?.toDouble() ?? 0.0,
      currency: map['currency'] as String? ?? 'INR',
      country: map['country'] as String? ?? 'India',
      monthlyEmi: (map['monthlyEmi'] as num?)?.toDouble() ?? 0.0,
      savingsGoal: (map['savingsGoal'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory UserProfile.fromJson(String source) {
    final decoded = jsonDecode(source) as Map<String, dynamic>;
    return UserProfile.fromMap(decoded);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is UserProfile &&
        other.id == id &&
        other.fullName == fullName &&
        other.email == email &&
        other.phone == phone &&
        other.dateOfBirth == dateOfBirth &&
        other.gender == gender &&
        other.occupation == occupation &&
        other.monthlyIncome == monthlyIncome &&
        other.currency == currency &&
        other.country == country &&
        other.monthlyEmi == monthlyEmi &&
        other.savingsGoal == savingsGoal &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      fullName,
      email,
      phone,
      dateOfBirth,
      gender,
      occupation,
      monthlyIncome,
      currency,
      Object.hash(country, monthlyEmi, savingsGoal, createdAt, updatedAt),
    );
  }
}
