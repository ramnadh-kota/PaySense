import 'package:hive/hive.dart';

part 'user_profile.g.dart';

@HiveType(typeId: 0)
class UserProfile {
  const UserProfile({
    required this.id,
    required this.fullName,
    required this.monthlyIncome,
    required this.monthlyEmi,
    required this.savingsGoal,
    required this.targetDate,
    required this.onboardingCompleted,
  });
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String fullName;
  @HiveField(2)
  final double monthlyIncome;
  @HiveField(3)
  final double monthlyEmi;
  @HiveField(4)
  final double savingsGoal;
  @HiveField(5)
  final DateTime targetDate;
  @HiveField(6)
  final bool onboardingCompleted;

  UserProfile copyWith({
    String? id,
    String? fullName,
    double? monthlyIncome,
    double? monthlyEmi,
    double? savingsGoal,
    DateTime? targetDate,
    bool? onboardingCompleted,
  }) {
    return UserProfile(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      monthlyIncome: monthlyIncome ?? this.monthlyIncome,
      monthlyEmi: monthlyEmi ?? this.monthlyEmi,
      savingsGoal: savingsGoal ?? this.savingsGoal,
      targetDate: targetDate ?? this.targetDate,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'fullName': fullName,
      'monthlyIncome': monthlyIncome,
      'monthlyEmi': monthlyEmi,
      'savingsGoal': savingsGoal,
      'targetDate': targetDate.toIso8601String(),
      'onboardingCompleted': onboardingCompleted,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] as String,
      fullName: map['fullName'] as String,
      monthlyIncome: (map['monthlyIncome'] as num).toDouble(),
      monthlyEmi: (map['monthlyEmi'] as num).toDouble(),
      savingsGoal: (map['savingsGoal'] as num).toDouble(),
      targetDate: DateTime.parse(map['targetDate'] as String),
      onboardingCompleted: map['onboardingCompleted'] as bool,
    );
  }
}
