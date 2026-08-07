import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

part 'goal.g.dart';

/// Represents a savings goal.
@immutable
@HiveType(typeId: 4)
class Goal {
  const Goal({
    required this.id,
    required this.title,
    required this.targetAmount,
    required this.currentAmount,
    required this.targetDate,
    required this.category,
    required this.icon,
    required this.color,
    required this.createdAt,
    required this.updatedAt,
    required this.isCompleted,
  });

  factory Goal.create({
    required String id,
    required String title,
    required double targetAmount,
    required DateTime targetDate,
    required String category,
    required String icon,
    required int color,
    required DateTime createdAt,
    double currentAmount = 0.0,
  }) {
    return Goal(
      id: id,
      title: title,
      targetAmount: targetAmount,
      currentAmount: currentAmount,
      targetDate: targetDate,
      category: category,
      icon: icon,
      color: color,
      createdAt: createdAt,
      updatedAt: createdAt,
      isCompleted: currentAmount >= targetAmount,
    );
  }

  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final double targetAmount;

  @HiveField(3)
  final double currentAmount;

  @HiveField(4)
  final DateTime targetDate;

  @HiveField(5)
  final String category;

  @HiveField(6)
  final String icon;

  @HiveField(7)
  final int color;

  @HiveField(8)
  final DateTime createdAt;

  @HiveField(9)
  final DateTime updatedAt;

  @HiveField(10)
  final bool isCompleted;

  double get remainingAmount =>
      (targetAmount - currentAmount).clamp(0.0, targetAmount);

  double get progressPercentage => targetAmount > 0
      ? (currentAmount / targetAmount * 100).clamp(0.0, 100.0)
      : 0.0;

  Goal copyWith({
    String? id,
    String? title,
    double? targetAmount,
    double? currentAmount,
    DateTime? targetDate,
    String? category,
    String? icon,
    int? color,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isCompleted,
  }) {
    return Goal(
      id: id ?? this.id,
      title: title ?? this.title,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      targetDate: targetDate ?? this.targetDate,
      category: category ?? this.category,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  /// Updates the saved amount and keeps [isCompleted] in sync.
  Goal updateProgress({required double currentAmount}) {
    return copyWith(
      currentAmount: currentAmount,
      isCompleted: currentAmount >= targetAmount,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'targetAmount': targetAmount,
      'currentAmount': currentAmount,
      'targetDate': targetDate.toIso8601String(),
      'category': category,
      'icon': icon,
      'color': color,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isCompleted': isCompleted,
    };
  }

  factory Goal.fromMap(Map<String, dynamic> map) {
    return Goal(
      id: map['id'] as String,
      title: map['title'] as String,
      targetAmount: (map['targetAmount'] as num).toDouble(),
      currentAmount: (map['currentAmount'] as num).toDouble(),
      targetDate: DateTime.parse(map['targetDate'] as String),
      category: map['category'] as String,
      icon: map['icon'] as String,
      color: map['color'] as int,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
      isCompleted: map['isCompleted'] as bool,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory Goal.fromJson(String source) {
    final decoded = jsonDecode(source) as Map<String, dynamic>;
    return Goal.fromMap(decoded);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is Goal &&
        other.id == id &&
        other.title == title &&
        other.targetAmount == targetAmount &&
        other.currentAmount == currentAmount &&
        other.targetDate == targetDate &&
        other.category == category &&
        other.icon == icon &&
        other.color == color &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.isCompleted == isCompleted;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      title,
      targetAmount,
      currentAmount,
      targetDate,
      category,
      icon,
      color,
      createdAt,
      updatedAt,
      isCompleted,
    );
  }
}
