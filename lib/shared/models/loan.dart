import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

part 'loan.g.dart';

/// Result of an EMI calculation for a given principal/rate/tenure.
class EmiCalculation {
  const EmiCalculation({
    required this.emiAmount,
    required this.totalInterest,
    required this.totalPayable,
  });

  final double emiAmount;
  final double totalInterest;
  final double totalPayable;
}

/// Represents a loan or EMI-based liability (home, personal, car, education,
/// credit card, etc.) tracked to completion via monthly EMI payments.
@immutable
@HiveType(typeId: 7)
class Loan {
  const Loan({
    required this.id,
    required this.loanName,
    required this.lenderName,
    required this.loanType,
    required this.principalAmount,
    required this.interestRate,
    required this.tenureMonths,
    required this.emiAmount,
    required this.outstandingAmount,
    required this.paidAmount,
    required this.accountId,
    required this.nextDueDate,
    required this.startDate,
    required this.endDate,
    required this.totalInterest,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Loan.create({
    required String id,
    required String loanName,
    required String lenderName,
    required String loanType,
    required double principalAmount,
    required double interestRate,
    required int tenureMonths,
    required double emiAmount,
    required double totalInterest,
    required String accountId,
    required DateTime startDate,
    required DateTime nextDueDate,
    required DateTime createdAt,
  }) {
    return Loan(
      id: id,
      loanName: loanName,
      lenderName: lenderName,
      loanType: loanType,
      principalAmount: principalAmount,
      interestRate: interestRate,
      tenureMonths: tenureMonths,
      emiAmount: emiAmount,
      outstandingAmount: principalAmount,
      paidAmount: 0,
      accountId: accountId,
      nextDueDate: nextDueDate,
      startDate: startDate,
      endDate: _addMonthsClamped(startDate, tenureMonths),
      totalInterest: totalInterest,
      status: 'Active',
      createdAt: createdAt,
      updatedAt: createdAt,
    );
  }

  @HiveField(0)
  final String id;

  @HiveField(1)
  final String loanName;

  @HiveField(2)
  final String lenderName;

  /// One of 'Home', 'Personal', 'Car', 'Education', 'Credit Card', 'Other'.
  @HiveField(3)
  final String loanType;

  @HiveField(4)
  final double principalAmount;

  /// Annual interest rate, as a percentage (e.g. 9.5 for 9.5%).
  @HiveField(5)
  final double interestRate;

  @HiveField(6)
  final int tenureMonths;

  @HiveField(7)
  final double emiAmount;

  @HiveField(8)
  final double outstandingAmount;

  @HiveField(9)
  final double paidAmount;

  /// Which wallet/account the EMI is paid from.
  @HiveField(10)
  final String accountId;

  @HiveField(11)
  final DateTime nextDueDate;

  @HiveField(12)
  final DateTime startDate;

  @HiveField(13)
  final DateTime endDate;

  @HiveField(14)
  final double totalInterest;

  /// One of 'Active', 'Closed'.
  @HiveField(15)
  final String status;

  @HiveField(16)
  final DateTime createdAt;

  @HiveField(17)
  final DateTime updatedAt;

  bool get isActive => status == 'Active';
  bool get isClosed => status == 'Closed';

  double get totalPayable => principalAmount + totalInterest;

  /// Rough proportional estimate of interest paid so far, since we don't
  /// keep a full amortization ledger: interest scales with the fraction of
  /// principal already repaid.
  double get estimatedInterestPaid {
    if (principalAmount <= 0) {
      return 0;
    }
    final principalRepaid = (principalAmount - outstandingAmount).clamp(
      0.0,
      principalAmount,
    );
    return totalInterest * (principalRepaid / principalAmount);
  }

  /// Same proportional-estimate approach for the interest still to come.
  double get estimatedInterestRemaining =>
      (totalInterest - estimatedInterestPaid).clamp(0.0, totalInterest);

  bool isOverdue(DateTime now) {
    if (!isActive) {
      return false;
    }
    final today = DateTime(now.year, now.month, now.day);
    return nextDueDate.isBefore(today);
  }

  bool isUpcoming(DateTime now, {int days = 7}) {
    if (!isActive || isOverdue(now)) {
      return false;
    }
    final horizon = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(Duration(days: days));
    return !nextDueDate.isAfter(horizon);
  }

  /// Computes the EMI, total interest, and total payable for a standard
  /// reducing-balance loan. Falls back to a simple even split when
  /// [annualRatePercent] is zero (interest-free loan).
  static EmiCalculation calculateEmi({
    required double principal,
    required double annualRatePercent,
    required int tenureMonths,
  }) {
    if (tenureMonths <= 0 || principal <= 0) {
      return const EmiCalculation(
        emiAmount: 0,
        totalInterest: 0,
        totalPayable: 0,
      );
    }

    if (annualRatePercent <= 0) {
      final emi = principal / tenureMonths;
      return EmiCalculation(
        emiAmount: emi,
        totalInterest: 0,
        totalPayable: principal,
      );
    }

    final monthlyRate = annualRatePercent / 12 / 100;
    final factor = _pow(1 + monthlyRate, tenureMonths);
    final emi = principal * monthlyRate * factor / (factor - 1);
    final totalPayable = emi * tenureMonths;
    final totalInterest = totalPayable - principal;

    return EmiCalculation(
      emiAmount: emi,
      totalInterest: totalInterest,
      totalPayable: totalPayable,
    );
  }

  static double _pow(double base, int exponent) {
    double result = 1;
    for (var i = 0; i < exponent; i++) {
      result *= base;
    }
    return result;
  }

  static DateTime _addMonthsClamped(DateTime from, int months) {
    final totalMonths = from.month - 1 + months;
    final year = from.year + totalMonths ~/ 12;
    final month = totalMonths % 12 + 1;
    final daysInTargetMonth = DateTime(year, month + 1, 0).day;
    final day = from.day > daysInTargetMonth ? daysInTargetMonth : from.day;
    return DateTime(year, month, day, from.hour, from.minute);
  }

  /// Records an EMI payment of [amount] (defaults to [emiAmount]) as of
  /// [paidAt]: reduces the outstanding balance, increases the paid amount,
  /// and either rolls the due date forward a month or closes the loan out
  /// once fully repaid.
  Loan markEmiPaid(DateTime paidAt, {double? amount}) {
    final paymentAmount = amount ?? emiAmount;
    final newOutstanding = (outstandingAmount - paymentAmount).clamp(
      0.0,
      principalAmount,
    );
    final isPaidOff = newOutstanding <= 0;

    return copyWith(
      outstandingAmount: newOutstanding,
      paidAmount: paidAmount + paymentAmount,
      nextDueDate: isPaidOff
          ? nextDueDate
          : _addMonthsClamped(nextDueDate, 1),
      status: isPaidOff ? 'Closed' : status,
      updatedAt: paidAt,
    );
  }

  Loan closeLoan(DateTime closedAt) {
    return copyWith(
      status: 'Closed',
      outstandingAmount: 0,
      updatedAt: closedAt,
    );
  }

  Loan copyWith({
    String? id,
    String? loanName,
    String? lenderName,
    String? loanType,
    double? principalAmount,
    double? interestRate,
    int? tenureMonths,
    double? emiAmount,
    double? outstandingAmount,
    double? paidAmount,
    String? accountId,
    DateTime? nextDueDate,
    DateTime? startDate,
    DateTime? endDate,
    double? totalInterest,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Loan(
      id: id ?? this.id,
      loanName: loanName ?? this.loanName,
      lenderName: lenderName ?? this.lenderName,
      loanType: loanType ?? this.loanType,
      principalAmount: principalAmount ?? this.principalAmount,
      interestRate: interestRate ?? this.interestRate,
      tenureMonths: tenureMonths ?? this.tenureMonths,
      emiAmount: emiAmount ?? this.emiAmount,
      outstandingAmount: outstandingAmount ?? this.outstandingAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      accountId: accountId ?? this.accountId,
      nextDueDate: nextDueDate ?? this.nextDueDate,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      totalInterest: totalInterest ?? this.totalInterest,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'loanName': loanName,
      'lenderName': lenderName,
      'loanType': loanType,
      'principalAmount': principalAmount,
      'interestRate': interestRate,
      'tenureMonths': tenureMonths,
      'emiAmount': emiAmount,
      'outstandingAmount': outstandingAmount,
      'paidAmount': paidAmount,
      'accountId': accountId,
      'nextDueDate': nextDueDate.toIso8601String(),
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'totalInterest': totalInterest,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Loan.fromMap(Map<String, dynamic> map) {
    return Loan(
      id: map['id'] as String,
      loanName: map['loanName'] as String,
      lenderName: map['lenderName'] as String,
      loanType: map['loanType'] as String,
      principalAmount: (map['principalAmount'] as num).toDouble(),
      interestRate: (map['interestRate'] as num).toDouble(),
      tenureMonths: map['tenureMonths'] as int,
      emiAmount: (map['emiAmount'] as num).toDouble(),
      outstandingAmount: (map['outstandingAmount'] as num).toDouble(),
      paidAmount: (map['paidAmount'] as num).toDouble(),
      accountId: map['accountId'] as String,
      nextDueDate: DateTime.parse(map['nextDueDate'] as String),
      startDate: DateTime.parse(map['startDate'] as String),
      endDate: DateTime.parse(map['endDate'] as String),
      totalInterest: (map['totalInterest'] as num).toDouble(),
      status: map['status'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory Loan.fromJson(String source) {
    final decoded = jsonDecode(source) as Map<String, dynamic>;
    return Loan.fromMap(decoded);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is Loan &&
        other.id == id &&
        other.loanName == loanName &&
        other.lenderName == lenderName &&
        other.loanType == loanType &&
        other.principalAmount == principalAmount &&
        other.interestRate == interestRate &&
        other.tenureMonths == tenureMonths &&
        other.emiAmount == emiAmount &&
        other.outstandingAmount == outstandingAmount &&
        other.paidAmount == paidAmount &&
        other.accountId == accountId &&
        other.nextDueDate == nextDueDate &&
        other.startDate == startDate &&
        other.endDate == endDate &&
        other.totalInterest == totalInterest &&
        other.status == status &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      loanName,
      lenderName,
      loanType,
      principalAmount,
      interestRate,
      tenureMonths,
      emiAmount,
      outstandingAmount,
      paidAmount,
      Object.hash(
        accountId,
        nextDueDate,
        startDate,
        endDate,
        totalInterest,
        status,
        createdAt,
        updatedAt,
      ),
    );
  }
}
