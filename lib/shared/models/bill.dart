import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

part 'bill.g.dart';

/// Represents a trackable bill or subscription with a due date and a
/// paid/unpaid status. Optionally recurring, in which case marking it paid
/// advances it to the next cycle instead of leaving it closed.
@immutable
@HiveType(typeId: 6)
class Bill {
  const Bill({
    required this.id,
    required this.title,
    required this.amount,
    required this.categoryId,
    required this.accountId,
    required this.dueDate,
    required this.isPaid,
    this.paidDate,
    required this.isRecurring,
    required this.frequency,
    required this.reminderDaysBefore,
    required this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Bill.create({
    required String id,
    required String title,
    required double amount,
    required String categoryId,
    required String accountId,
    required DateTime dueDate,
    bool isRecurring = false,
    String frequency = 'Monthly',
    int reminderDaysBefore = 2,
    String note = '',
    required DateTime createdAt,
  }) {
    return Bill(
      id: id,
      title: title,
      amount: amount,
      categoryId: categoryId,
      accountId: accountId,
      dueDate: dueDate,
      isPaid: false,
      paidDate: null,
      isRecurring: isRecurring,
      frequency: frequency,
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
  final DateTime dueDate;

  @HiveField(6)
  final bool isPaid;

  @HiveField(7)
  final DateTime? paidDate;

  @HiveField(8)
  final bool isRecurring;

  /// One of 'Weekly', 'Monthly', 'Yearly'. Only meaningful when
  /// [isRecurring] is true.
  @HiveField(9)
  final String frequency;

  @HiveField(10)
  final int reminderDaysBefore;

  @HiveField(11)
  final String note;

  @HiveField(12)
  final DateTime createdAt;

  @HiveField(13)
  final DateTime updatedAt;

  /// True once [dueDate]'s calendar day has passed without payment.
  bool isOverdue(DateTime now) {
    if (isPaid) {
      return false;
    }
    final today = DateTime(now.year, now.month, now.day);
    return dueDate.isBefore(today);
  }

  /// True when unpaid and due within [days] (inclusive), but not overdue.
  bool isUpcoming(DateTime now, {int days = 7}) {
    if (isPaid || isOverdue(now)) {
      return false;
    }
    final horizon = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(Duration(days: days));
    return !dueDate.isAfter(horizon);
  }

  DateTime get reminderDate =>
      dueDate.subtract(Duration(days: reminderDaysBefore));

  /// Computes the next occurrence date after [from] for the given
  /// [frequency]. Falls back to a monthly cadence for unrecognized values.
  static DateTime computeNextDueDate(DateTime from, String frequency) {
    switch (frequency) {
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

  /// Marks this bill paid as of [paidAt]. Recurring bills roll forward to
  /// their next due date and reopen as unpaid; one-off bills stay closed.
  Bill markPaid(DateTime paidAt) {
    if (isRecurring) {
      return copyWith(
        isPaid: false,
        paidDate: paidAt,
        dueDate: computeNextDueDate(dueDate, frequency),
        updatedAt: paidAt,
      );
    }
    return copyWith(isPaid: true, paidDate: paidAt, updatedAt: paidAt);
  }

  Bill markUnpaid() {
    return copyWith(
      isPaid: false,
      clearPaidDate: true,
      updatedAt: DateTime.now(),
    );
  }

  Bill copyWith({
    String? id,
    String? title,
    double? amount,
    String? categoryId,
    String? accountId,
    DateTime? dueDate,
    bool? isPaid,
    DateTime? paidDate,
    bool clearPaidDate = false,
    bool? isRecurring,
    String? frequency,
    int? reminderDaysBefore,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Bill(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      categoryId: categoryId ?? this.categoryId,
      accountId: accountId ?? this.accountId,
      dueDate: dueDate ?? this.dueDate,
      isPaid: isPaid ?? this.isPaid,
      paidDate: clearPaidDate ? null : (paidDate ?? this.paidDate),
      isRecurring: isRecurring ?? this.isRecurring,
      frequency: frequency ?? this.frequency,
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
      'dueDate': dueDate.toIso8601String(),
      'isPaid': isPaid,
      'paidDate': paidDate?.toIso8601String(),
      'isRecurring': isRecurring,
      'frequency': frequency,
      'reminderDaysBefore': reminderDaysBefore,
      'note': note,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Bill.fromMap(Map<String, dynamic> map) {
    return Bill(
      id: map['id'] as String,
      title: map['title'] as String,
      amount: (map['amount'] as num).toDouble(),
      categoryId: map['categoryId'] as String,
      accountId: map['accountId'] as String,
      dueDate: DateTime.parse(map['dueDate'] as String),
      isPaid: map['isPaid'] as bool,
      paidDate: map['paidDate'] == null
          ? null
          : DateTime.parse(map['paidDate'] as String),
      isRecurring: map['isRecurring'] as bool,
      frequency: map['frequency'] as String,
      reminderDaysBefore: map['reminderDaysBefore'] as int,
      note: map['note'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory Bill.fromJson(String source) {
    final decoded = jsonDecode(source) as Map<String, dynamic>;
    return Bill.fromMap(decoded);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is Bill &&
        other.id == id &&
        other.title == title &&
        other.amount == amount &&
        other.categoryId == categoryId &&
        other.accountId == accountId &&
        other.dueDate == dueDate &&
        other.isPaid == isPaid &&
        other.paidDate == paidDate &&
        other.isRecurring == isRecurring &&
        other.frequency == frequency &&
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
      dueDate,
      isPaid,
      paidDate,
      isRecurring,
      Object.hash(frequency, reminderDaysBefore, note, createdAt, updatedAt),
    );
  }
}
