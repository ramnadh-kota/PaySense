// FUN FUNDS — FRIENDS/GROUP EXPENSES. Equal-split rounding must never
// lose or fabricate a paisa: sum(parts) == original amount, exactly, for
// every participant count — including ones that don't divide evenly.
import 'package:flutter_test/flutter_test.dart';
import 'package:paysense/shared/models/fun_funds_expense.dart';
import 'package:paysense/shared/models/fun_funds_group.dart';
import 'package:paysense/shared/models/fun_funds_settlement.dart';
import 'package:paysense/shared/utils/group_expense_calculator.dart';

double _sum(List<double> values) => values.fold<double>(0, (a, b) => a + b);

FunFundsExpense _expense({
  required String id,
  required double amount,
  required String payer,
  required List<String> participants,
  String groupId = 'g1',
}) {
  return FunFundsExpense(
    id: id,
    groupId: groupId,
    description: 'Expense $id',
    totalAmount: amount,
    payerName: payer,
    participantNames: participants,
    createdAt: DateTime(2026, 8, 1),
  );
}

void main() {
  group('1. Equal split — exact rounding', () {
    test('₹3,000 across 4 people is exactly ₹750 each (the spec example)', () {
      final shares = GroupExpenseCalculator.equalSplit(3000, 4);
      expect(shares, [750, 750, 750, 750]);
      expect(_sum(shares), 3000);
    });

    test('₹100 / 3 does not divide evenly: sum(parts) still equals exactly ₹100', () {
      final shares = GroupExpenseCalculator.equalSplit(100, 3);
      expect(_sum(shares), 100);
      // Residual paise go to the first participant(s) in order — never a
      // random member, always deterministic given the same input.
      expect(shares[0], 33.34);
      expect(shares[1], 33.33);
      expect(shares[2], 33.33);
    });

    test('₹1,000 / 6 does not divide evenly: sum(parts) still equals exactly ₹1,000', () {
      final shares = GroupExpenseCalculator.equalSplit(1000, 6);
      expect(_sum(shares), closeTo(1000, 1e-9));
      // 100000 paise / 6 = base 16666, remainder 4 -> first 4 participants
      // get the extra paisa (166.67), the last 2 get the base (166.66).
      for (var i = 0; i < 4; i++) {
        expect(shares[i], 166.67);
      }
      for (var i = 4; i < 6; i++) {
        expect(shares[i], 166.66);
      }
    });

    test('₹999.99 across 4 people: sum(parts) equals exactly ₹999.99', () {
      final shares = GroupExpenseCalculator.equalSplit(999.99, 4);
      expect(_sum(shares), closeTo(999.99, 1e-9));
    });

    test('₹0.01 across 3 people: one person gets it, the others get 0, sum is exact', () {
      final shares = GroupExpenseCalculator.equalSplit(0.01, 3);
      expect(_sum(shares), 0.01);
      expect(shares[0], 0.01);
      expect(shares[1], 0);
      expect(shares[2], 0);
    });

    test('a large amount splits without float drift', () {
      final shares = GroupExpenseCalculator.equalSplit(1234567.89, 7);
      expect(_sum(shares), closeTo(1234567.89, 1e-6));
    });

    test('splitting is deterministic — calling twice with the same input gives the same result', () {
      final a = GroupExpenseCalculator.equalSplit(100, 3);
      final b = GroupExpenseCalculator.equalSplit(100, 3);
      expect(a, b);
    });

    test('1 participant: ₹500 across 1 person is exactly ₹500', () {
      final shares = GroupExpenseCalculator.equalSplit(500, 1);
      expect(shares, [500]);
    });

    test('0 participants returns an empty split, never a crash or divide-by-zero', () {
      expect(GroupExpenseCalculator.equalSplit(100, 0), isEmpty);
    });

    test('negative participants returns an empty split, never a crash', () {
      expect(GroupExpenseCalculator.equalSplit(100, -2), isEmpty);
    });

    test('0 amount returns 0s for all participants', () {
      final shares = GroupExpenseCalculator.equalSplit(0, 3);
      expect(shares, [0, 0, 0]);
      expect(_sum(shares), 0);
    });

    test('negative amount handles gracefully without crash', () {
      final shares = GroupExpenseCalculator.equalSplit(-100, 2);
      expect(_sum(shares), -100);
    });
  });

  group('2. Debts derived from an expense', () {
    test('Ram paid ₹3,000 for 4 people: each of the other 3 owes Ram ₹750 (the spec example)', () {
      final expense = _expense(
        id: 'e1',
        amount: 3000,
        payer: 'Ram',
        participants: ['Ram', 'Priya', 'Amit', 'Sara'],
      );
      final debts = GroupExpenseCalculator.debtsFor(expense, settledDebtorNames: const {});
      expect(debts, hasLength(3));
      expect(debts.every((d) => d.creditorName == 'Ram'), isTrue);
      expect(debts.every((d) => d.amount == 750), isTrue);
      expect(debts.map((d) => d.debtorName).toSet(), {'Priya', 'Amit', 'Sara'});
    });

    test('the payer never owes themselves', () {
      final expense = _expense(id: 'e1', amount: 100, payer: 'Ram', participants: ['Ram']);
      expect(GroupExpenseCalculator.debtsFor(expense, settledDebtorNames: const {}), isEmpty);
    });

    test('a payer covering others without taking a share themselves owes nothing and is owed the full amount', () {
      final expense = _expense(
        id: 'e1',
        amount: 200,
        payer: 'Ram',
        participants: ['Priya', 'Amit'], // Ram excluded — treats himself
      );
      final debts = GroupExpenseCalculator.debtsFor(expense, settledDebtorNames: const {});
      expect(debts, hasLength(2));
      expect(_sum(debts.map((d) => d.amount).toList()), 200);
    });

    test('a settled debtor name is flagged isSettled, others remain pending', () {
      final expense = _expense(
        id: 'e1', amount: 3000, payer: 'Ram', participants: ['Ram', 'Priya', 'Amit', 'Sara'],
      );
      final debts = GroupExpenseCalculator.debtsFor(expense, settledDebtorNames: {'Priya'});
      final priyaDebt = debts.firstWhere((d) => d.debtorName == 'Priya');
      final amitDebt = debts.firstWhere((d) => d.debtorName == 'Amit');
      expect(priyaDebt.isSettled, isTrue);
      expect(amitDebt.isSettled, isFalse);
    });
  });

  group('3. Net balances across a group', () {
    test('a single expense: payer is owed, participants owe, balances net to zero', () {
      final group = FunFundsGroup(
        id: 'g1', name: 'Goa Trip', memberNames: const ['Ram', 'Priya', 'Amit', 'Sara'],
        createdAt: DateTime(2026, 8, 1),
      );
      final expense = _expense(
        id: 'e1', amount: 3000, payer: 'Ram', participants: ['Ram', 'Priya', 'Amit', 'Sara'],
      );
      final balances = GroupExpenseCalculator.netBalances(
        group: group, expenses: [expense], settlements: const [],
      );
      final ram = balances.firstWhere((b) => b.memberName == 'Ram');
      expect(ram.netAmount, 2250); // owed 750 x 3
      expect(ram.isOwed, isTrue);
      for (final name in ['Priya', 'Amit', 'Sara']) {
        final b = balances.firstWhere((b) => b.memberName == name);
        expect(b.netAmount, -750);
        expect(b.owes, isTrue);
      }
      // Every group's net balances must sum to exactly 0 — money doesn't
      // appear or vanish, it only moves between members.
      expect(_sum(balances.map((b) => b.netAmount).toList()), closeTo(0, 1e-9));
    });

    test('settling a debt removes it from net balances entirely', () {
      final group = FunFundsGroup(
        id: 'g1', name: 'Goa Trip', memberNames: const ['Ram', 'Priya'],
        createdAt: DateTime(2026, 8, 1),
      );
      final expense = _expense(id: 'e1', amount: 1000, payer: 'Ram', participants: ['Ram', 'Priya']);
      final settlement = FunFundsSettlement(
        id: 'e1:Priya', groupId: 'g1', expenseId: 'e1', debtorName: 'Priya',
        settledAt: DateTime(2026, 8, 2),
      );

      final beforeSettlement = GroupExpenseCalculator.netBalances(
        group: group, expenses: [expense], settlements: const [],
      );
      final afterSettlement = GroupExpenseCalculator.netBalances(
        group: group, expenses: [expense], settlements: [settlement],
      );

      expect(beforeSettlement.firstWhere((b) => b.memberName == 'Priya').netAmount, -500);
      expect(afterSettlement.firstWhere((b) => b.memberName == 'Priya').netAmount, 0);
      expect(afterSettlement.firstWhere((b) => b.memberName == 'Ram').netAmount, 0);
    });

    test('a group with no expenses yet: everyone is square, never a fabricated balance', () {
      final group = FunFundsGroup(
        id: 'g1', name: 'New Group', memberNames: const ['Ram', 'Priya'],
        createdAt: DateTime(2026, 8, 1),
      );
      final balances = GroupExpenseCalculator.netBalances(group: group, expenses: const [], settlements: const []);
      expect(balances.every((b) => b.isSquare), isTrue);
    });

    test('multiple expenses across the same group net correctly', () {
      final group = FunFundsGroup(
        id: 'g1', name: 'Flatmates', memberNames: const ['Ram', 'Priya', 'Amit'],
        createdAt: DateTime(2026, 8, 1),
      );
      final expenses = [
        _expense(id: 'e1', amount: 300, payer: 'Ram', participants: ['Ram', 'Priya', 'Amit']),
        _expense(id: 'e2', amount: 300, payer: 'Priya', participants: ['Ram', 'Priya', 'Amit']),
      ];
      final balances = GroupExpenseCalculator.netBalances(group: group, expenses: expenses, settlements: const []);
      // e1 (Ram pays ₹300, split 3 ways): Priya -100, Amit -100, Ram +200.
      // e2 (Priya pays ₹300, split 3 ways): Ram -100, Amit -100, Priya +200.
      // Net: Ram +200-100=+100, Priya -100+200=+100, Amit -100-100=-200.
      expect(balances.firstWhere((b) => b.memberName == 'Ram').netAmount, 100);
      expect(balances.firstWhere((b) => b.memberName == 'Priya').netAmount, 100);
      expect(balances.firstWhere((b) => b.memberName == 'Amit').netAmount, -200);
      expect(_sum(balances.map((b) => b.netAmount).toList()), closeTo(0, 1e-9));
    });
  });

  group('4. Group total', () {
    test('sums every expense regardless of settlement status', () {
      final expenses = [
        _expense(id: 'e1', amount: 500, payer: 'Ram', participants: ['Ram', 'Priya']),
        _expense(id: 'e2', amount: 300, payer: 'Priya', participants: ['Ram', 'Priya']),
      ];
      expect(GroupExpenseCalculator.groupTotal(expenses), 800);
    });

    test('an empty group totals ₹0, not a fabricated figure', () {
      expect(GroupExpenseCalculator.groupTotal(const []), 0);
    });
  });
}
