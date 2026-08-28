import 'package:flutter/foundation.dart';

import '../models/fun_funds_expense.dart';
import '../models/fun_funds_group.dart';
import '../models/fun_funds_settlement.dart';

/// One participant's equal-split share of one [FunFundsExpense] that isn't
/// the payer's own share — i.e. money owed.
@immutable
class GroupDebt {
  const GroupDebt({
    required this.expenseId,
    required this.expenseDescription,
    required this.debtorName,
    required this.creditorName,
    required this.amount,
    required this.isSettled,
  });

  final String expenseId;
  final String expenseDescription;
  final String debtorName;
  final String creditorName;
  final double amount;
  final bool isSettled;
}

/// A single group member's net position across every UNSETTLED debt in the
/// group: positive means the group owes them money, negative means they
/// owe the group money, 0 means they're square.
@immutable
class GroupMemberBalance {
  const GroupMemberBalance({required this.memberName, required this.netAmount});

  final String memberName;
  final double netAmount;

  bool get isOwed => netAmount > 0;
  bool get owes => netAmount < 0;
  bool get isSquare => netAmount == 0;
}

class GroupExpenseCalculator {
  GroupExpenseCalculator._();

  /// Splits [totalAmount] into [participantCount] equal shares whose sum
  /// is EXACTLY [totalAmount] to the paisa — never loses or fabricates a
  /// paisa to floating-point rounding. Works in integer paise
  /// (`round(amount*100)`), distributes the base share to everyone, then
  /// hands the leftover 0..(n-1) paise one each to the FIRST participants
  /// in list order — a fixed, deterministic (not random) allocation, so
  /// calling this twice with the same inputs always produces the same
  /// split.
  static List<double> equalSplit(double totalAmount, int participantCount) {
    if (participantCount <= 0) return const [];
    final totalPaise = (totalAmount * 100).round();
    final basePaise = totalPaise ~/ participantCount;
    final remainderPaise = totalPaise - basePaise * participantCount;
    return List<double>.generate(participantCount, (i) {
      final paise = basePaise + (i < remainderPaise ? 1 : 0);
      return paise / 100;
    });
  }

  /// Every debt this expense creates: each participant other than the
  /// payer owes the payer their equal share. A participant who IS the
  /// payer owes nothing to themselves (their own share is simply money
  /// they already paid).
  static List<GroupDebt> debtsFor(
    FunFundsExpense expense, {
    required Set<String> settledDebtorNames,
  }) {
    final shares = equalSplit(expense.totalAmount, expense.participantNames.length);
    final debts = <GroupDebt>[];
    for (var i = 0; i < expense.participantNames.length; i++) {
      final participant = expense.participantNames[i];
      if (participant == expense.payerName) continue;
      debts.add(
        GroupDebt(
          expenseId: expense.id,
          expenseDescription: expense.description,
          debtorName: participant,
          creditorName: expense.payerName,
          amount: shares[i],
          isSettled: settledDebtorNames.contains(participant),
        ),
      );
    }
    return debts;
  }

  /// Every debt across every expense in the group, each flagged
  /// Pending/Settled via [settlements] (a settlement record's mere
  /// presence for an (expenseId, debtorName) pair means that one debt is
  /// settled — see FunFundsSettlement's doc comment).
  static List<GroupDebt> allDebts({
    required List<FunFundsExpense> expenses,
    required List<FunFundsSettlement> settlements,
  }) {
    final debts = <GroupDebt>[];
    for (final expense in expenses) {
      final settledNames = settlements
          .where((s) => s.expenseId == expense.id)
          .map((s) => s.debtorName)
          .toSet();
      debts.addAll(debtsFor(expense, settledDebtorNames: settledNames));
    }
    return debts;
  }

  /// Net balance per [group] member across every UNSETTLED debt — the
  /// "who owes whom, in total" view. Members with no expenses at all are
  /// still included, at 0.
  static List<GroupMemberBalance> netBalances({
    required FunFundsGroup group,
    required List<FunFundsExpense> expenses,
    required List<FunFundsSettlement> settlements,
  }) {
    final balances = {for (final member in group.memberNames) member: 0.0};
    for (final debt in allDebts(expenses: expenses, settlements: settlements)) {
      if (debt.isSettled) continue;
      balances[debt.debtorName] = (balances[debt.debtorName] ?? 0) - debt.amount;
      balances[debt.creditorName] = (balances[debt.creditorName] ?? 0) + debt.amount;
    }
    return group.memberNames
        .map((member) => GroupMemberBalance(memberName: member, netAmount: balances[member] ?? 0))
        .toList();
  }

  /// Sum of every expense recorded in the group, regardless of settlement
  /// status — "how much has this group spent together."
  static double groupTotal(List<FunFundsExpense> expenses) {
    return expenses.fold<double>(0, (sum, e) => sum + e.totalAmount);
  }
}
