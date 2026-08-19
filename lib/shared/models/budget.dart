import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

part 'budget.g.dart';

/// Represents a category budget for a specific month.
@immutable
@HiveType(typeId: 3)
class Budget {
  const Budget({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.allocatedAmount,
    required this.spentAmount,
    required this.remainingAmount,
    required this.percentageUsed,
    required this.month,
    required this.year,
    required this.createdAt,
  });

  factory Budget.create({
    required String id,
    required String categoryId,
    required String categoryName,
    required double allocatedAmount,
    required String month,
    required int year,
    required DateTime createdAt,
  }) {
    final spentAmount = 0.0;
    final remainingAmount = allocatedAmount;
    final percentageUsed = allocatedAmount > 0 ? 0.0 : 0.0;

    return Budget(
      id: id,
      categoryId: categoryId,
      categoryName: categoryName,
      allocatedAmount: allocatedAmount,
      spentAmount: spentAmount,
      remainingAmount: remainingAmount,
      percentageUsed: percentageUsed,
      month: month,
      year: year,
      createdAt: createdAt,
    );
  }

  @HiveField(0)
  final String id;

  @HiveField(1)
  final String categoryId;

  @HiveField(2)
  final String categoryName;

  @HiveField(3)
  final double allocatedAmount;

  @HiveField(4)
  final double spentAmount;

  @HiveField(5)
  final double remainingAmount;

  @HiveField(6)
  final double percentageUsed;

  @HiveField(7)
  final String month;

  @HiveField(8)
  final int year;

  @HiveField(9)
  final DateTime createdAt;

  Budget copyWith({
    String? id,
    String? categoryId,
    String? categoryName,
    double? allocatedAmount,
    double? spentAmount,
    double? remainingAmount,
    double? percentageUsed,
    String? month,
    int? year,
    DateTime? createdAt,
  }) {
    return Budget(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      allocatedAmount: allocatedAmount ?? this.allocatedAmount,
      spentAmount: spentAmount ?? this.spentAmount,
      remainingAmount: remainingAmount ?? this.remainingAmount,
      percentageUsed: percentageUsed ?? this.percentageUsed,
      month: month ?? this.month,
      year: year ?? this.year,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Deliberately NOT clamped: [remainingAmount] goes negative once
  /// [spentAmount] exceeds [allocatedAmount] (a true "₹2,000 over budget"
  /// rather than a floored ₹0 that hides the overspend), and
  /// [percentageUsed] can exceed 100 for the same reason. `allocatedAmount
  /// <= 0` is the only case guarded against — that would otherwise divide
  /// by zero — and is reported as 0% rather than NaN/Infinity.
  Budget updateMetrics({required double spentAmount}) {
    final remainingAmount = allocatedAmount - spentAmount;
    final percentageUsed = allocatedAmount > 0
        ? (spentAmount / allocatedAmount * 100)
        : 0.0;
    return copyWith(
      spentAmount: spentAmount,
      remainingAmount: remainingAmount,
      percentageUsed: percentageUsed,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'allocatedAmount': allocatedAmount,
      'spentAmount': spentAmount,
      'remainingAmount': remainingAmount,
      'percentageUsed': percentageUsed,
      'month': month,
      'year': year,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Budget.fromMap(Map<String, dynamic> map) {
    return Budget(
      id: map['id'] as String,
      categoryId: map['categoryId'] as String,
      categoryName: map['categoryName'] as String,
      allocatedAmount: (map['allocatedAmount'] as num).toDouble(),
      spentAmount: (map['spentAmount'] as num).toDouble(),
      remainingAmount: (map['remainingAmount'] as num).toDouble(),
      percentageUsed: (map['percentageUsed'] as num).toDouble(),
      month: map['month'] as String,
      year: map['year'] as int,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory Budget.fromJson(String source) {
    final decoded = jsonDecode(source) as Map<String, dynamic>;
    return Budget.fromMap(decoded);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is Budget &&
        other.id == id &&
        other.categoryId == categoryId &&
        other.categoryName == categoryName &&
        other.allocatedAmount == allocatedAmount &&
        other.spentAmount == spentAmount &&
        other.remainingAmount == remainingAmount &&
        other.percentageUsed == percentageUsed &&
        other.month == month &&
        other.year == year &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      categoryId,
      categoryName,
      allocatedAmount,
      spentAmount,
      remainingAmount,
      percentageUsed,
      month,
      year,
      createdAt,
    );
  }
}
