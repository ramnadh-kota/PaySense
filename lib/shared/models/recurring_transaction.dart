import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

part 'recurring_transaction.g.dart';

/// Represents a recurring income or expense definition that generates real
/// [Transaction] entries automatically when due.
@immutable
@HiveType(typeId: 5)
class RecurringTransaction {
  const RecurringTransaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.categoryId,
    required this.accountId,
    required this.transactionType,
    required this.frequency,
    required this.startDate,
    required this.nextDueDate,
    this.endDate,
    this.lastGeneratedDate,
    required this.isActive,
    required this.reminderDaysBefore,
    required this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RecurringTransaction.create({
    required String id,
    required String title,
    required double amount,
    required String categoryId,
    required String accountId,
    required String transactionType,
    required String frequency,
    required DateTime startDate,
    DateTime? endDate,
    int reminderDaysBefore = 1,
    String note = '',
    required DateTime createdAt,
  }) {
    return RecurringTransaction(
      id: id,
      title: title,
      amount: amount,
      categoryId: categoryId,
      accountId: accountId,
      transactionType: transactionType,
      frequency: frequency,
      startDate: startDate,
      nextDueDate: startDate,
      endDate: endDate,
      lastGeneratedDate: null,
      isActive: true,
      reminderDaysBefore: reminderDaysBefore,
      note: note,
      createdAt: createdAt,
      updatedAt: createdAt,
    );
  }

  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final double amount;

  @HiveField(3)
  final String categoryId;

  @HiveField(4)
  final String accountId;

  @HiveField(5)
  final String transactionType;

  /// One of 'Daily', 'Weekly', 'Monthly', 'Yearly'.
  @HiveField(6)
  final String frequency;

  @HiveField(7)
  final DateTime startDate;

  @HiveField(8)
  final DateTime nextDueDate;

  @HiveField(9)
  final DateTime? endDate;

  @HiveField(10)
  final DateTime? lastGeneratedDate;

  @HiveField(11)
  final bool isActive;

  @HiveField(12)
  final int reminderDaysBefore;

  @HiveField(13)
  final String note;

  @HiveField(14)
  final DateTime createdAt;

  @HiveField(15)
  final DateTime updatedAt;

  /// Whether this recurring definition has passed its [endDate], if any.
  bool get isExpired => endDate != null && nextDueDate.isAfter(endDate!);

  /// Whether an occurrence is currently due relative to [now].
  bool isDue(DateTime now) {
    if (!isActive || isExpired) {
      return false;
    }
    return !nextDueDate.isAfter(now);
  }

  /// The date on which a reminder notification should fire for the current
  /// [nextDueDate], accounting for [reminderDaysBefore].
  DateTime get reminderDate =>
      nextDueDate.subtract(Duration(days: reminderDaysBefore));

  /// [amount] normalized to a monthly-equivalent figure based on
  /// [frequency], so totals across mixed-cadence recurring items (e.g. one
  /// yearly plus several monthly) can be summed meaningfully.
  double get monthlyEquivalentAmount {
    switch (frequency) {
      case 'Daily':
        return amount * 30;
      case 'Weekly':
        return amount * (30 / 7);
      case 'Yearly':
        return amount / 12;
      case 'Monthly':
      default:
        return amount;
    }
  }

  /// Computes the next occurrence date after [from] for the given
  /// [frequency]. Falls back to a monthly cadence for unrecognized values.
  static DateTime computeNextDueDate(DateTime from, String frequency) {
    switch (frequency) {
      case 'Daily':
        return from.add(const Duration(days: 1));
      case 'Weekly':
        return from.add(const Duration(days: 7));
      case 'Yearly':
        return DateTime(from.year + 1, from.month, from.day, from.hour, from.minute);
      case 'Monthly':
      default:
        final month = from.month == 12 ? 1 : from.month + 1;
        final year = from.month == 12 ? from.year + 1 : from.year;
        final daysInTargetMonth = DateTime(year, month + 1, 0).day;
        final day = from.day > daysInTargetMonth ? daysInTargetMonth : from.day;
        return DateTime(year, month, day, from.hour, from.minute);
    }
  }

  /// Returns a copy advanced to the next occurrence after [nextDueDate],
  /// recording [generatedAt] as the last generation timestamp.
  RecurringTransaction advance(DateTime generatedAt) {
    return copyWith(
      nextDueDate: computeNextDueDate(nextDueDate, frequency),
      lastGeneratedDate: generatedAt,
      updatedAt: generatedAt,
    );
  }

  RecurringTransaction copyWith({
    String? id,
    String? title,
    double? amount,
    String? categoryId,
    String? accountId,
    String? transactionType,
    String? frequency,
    DateTime? startDate,
    DateTime? nextDueDate,
    DateTime? endDate,
    bool clearEndDate = false,
    DateTime? lastGeneratedDate,
    bool? isActive,
    int? reminderDaysBefore,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RecurringTransaction(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      categoryId: categoryId ?? this.categoryId,
      accountId: accountId ?? this.accountId,
      transactionType: transactionType ?? this.transactionType,
      frequency: frequency ?? this.frequency,
      startDate: startDate ?? this.startDate,
      nextDueDate: nextDueDate ?? this.nextDueDate,
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      lastGeneratedDate: lastGeneratedDate ?? this.lastGeneratedDate,
      isActive: isActive ?? this.isActive,
      reminderDaysBefore: reminderDaysBefore ?? this.reminderDaysBefore,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'amount': amount,
      'categoryId': categoryId,
      'accountId': accountId,
      'transactionType': transactionType,
      'frequency': frequency,
      'startDate': startDate.toIso8601String(),
      'nextDueDate': nextDueDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'lastGeneratedDate': lastGeneratedDate?.toIso8601String(),
      'isActive': isActive,
      'reminderDaysBefore': reminderDaysBefore,
      'note': note,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory RecurringTransaction.fromMap(Map<String, dynamic> map) {
    return RecurringTransaction(
      id: map['id'] as String,
      title: map['title'] as String,
      amount: (map['amount'] as num).toDouble(),
      categoryId: map['categoryId'] as String,
      accountId: map['accountId'] as String,
      transactionType: map['transactionType'] as String,
      frequency: map['frequency'] as String,
      startDate: DateTime.parse(map['startDate'] as String),
      nextDueDate: DateTime.parse(map['nextDueDate'] as String),
      endDate: map['endDate'] == null
          ? null
          : DateTime.parse(map['endDate'] as String),
      lastGeneratedDate: map['lastGeneratedDate'] == null
          ? null
          : DateTime.parse(map['lastGeneratedDate'] as String),
      isActive: map['isActive'] as bool,
      reminderDaysBefore: map['reminderDaysBefore'] as int,
      note: map['note'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory RecurringTransaction.fromJson(String source) {
    final decoded = jsonDecode(source) as Map<String, dynamic>;
    return RecurringTransaction.fromMap(decoded);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is RecurringTransaction &&
        other.id == id &&
        other.title == title &&
        other.amount == amount &&
        other.categoryId == categoryId &&
        other.accountId == accountId &&
        other.transactionType == transactionType &&
        other.frequency == frequency &&
        other.startDate == startDate &&
        other.nextDueDate == nextDueDate &&
        other.endDate == endDate &&
        other.lastGeneratedDate == lastGeneratedDate &&
        other.isActive == isActive &&
        other.reminderDaysBefore == reminderDaysBefore &&
        other.note == note &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      title,
      amount,
      categoryId,
      accountId,
      transactionType,
      frequency,
      startDate,
      nextDueDate,
      Object.hash(endDate, lastGeneratedDate),
      isActive,
      reminderDaysBefore,
      note,
      createdAt,
      updatedAt,
    );
  }
}
