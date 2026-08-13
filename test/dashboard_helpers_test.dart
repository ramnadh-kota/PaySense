import 'package:flutter_test/flutter_test.dart';
import 'package:paysense/shared/models/bill.dart';
import 'package:paysense/shared/models/goal.dart';
import 'package:paysense/shared/models/recurring_transaction.dart';
import 'package:paysense/shared/models/transaction.dart';
import 'package:paysense/shared/providers/loan_provider.dart' show LoanSummary;
import 'package:paysense/shared/utils/dashboard_helpers.dart';

Transaction _tx({
  required String id,
  required double amount,
  required String type,
  required DateTime createdAt,
}) {
  return Transaction(
    id: id,
    title: 'Test $id',
    amount: amount,
    categoryId: 'General',
    accountId: 'Cash',
    transactionType: type,
    paymentMethod: '',
    note: '',
    createdAt: createdAt,
  );
}

LoanSummary _emptyLoanSummary() {
  return LoanSummary(
    totalLoans: 0,
    activeLoans: 0,
    closedLoans: 0,
    outstandingBalance: 0,
    totalEmiPerMonth: 0,
    totalInterest: 0,
    nextEmiLoanName: '',
    nextEmiAmount: 0,
    nextEmiDate: null,
  );
}

void main() {
  final now = DateTime(2026, 8, 13, 12, 0);

  group('greetingFor', () {
    test('uses the first name and time of day when a profile name exists', () {
      expect(greetingFor(DateTime(2026, 8, 13, 9, 0), 'Jane Doe'), 'Good Morning, Jane 👋');
      expect(greetingFor(DateTime(2026, 8, 13, 14, 0), 'Jane Doe'), 'Good Afternoon, Jane 👋');
      expect(greetingFor(DateTime(2026, 8, 13, 20, 0), 'Jane Doe'), 'Good Evening, Jane 👋');
    });

    test('falls back to a safe greeting when there is no profile name', () {
      expect(greetingFor(now, ''), 'Welcome back 👋');
      expect(greetingFor(now, '   '), 'Welcome back 👋');
    });
  });

  group('computeTodaysMoney', () {
    test('sums only today\'s income/expense and computes net', () {
      final transactions = [
        _tx(id: 't1', amount: 500, type: 'expense', createdAt: now),
        _tx(id: 't2', amount: 350, type: 'expense', createdAt: now),
        _tx(id: 't3', amount: 2000, type: 'income', createdAt: now),
        _tx(id: 't4', amount: 999, type: 'expense', createdAt: now.subtract(const Duration(days: 1))),
      ];

      final summary = computeTodaysMoney(transactions, now);
      expect(summary.spent, 850);
      expect(summary.income, 2000);
      expect(summary.net, 1150);
      expect(summary.hasActivity, isTrue);
    });

    test('reports no activity when there are no transactions today', () {
      final transactions = [
        _tx(id: 't1', amount: 999, type: 'expense', createdAt: now.subtract(const Duration(days: 2))),
      ];
      final summary = computeTodaysMoney(transactions, now);
      expect(summary.hasActivity, isFalse);
      expect(summary.spent, 0);
      expect(summary.income, 0);
    });
  });

  group('selectUpcomingAttention', () {
    test('prioritizes an overdue bill over everything else', () {
      final overdueBill = Bill.create(
        id: 'b1',
        title: 'Electricity',
        amount: 1200,
        categoryId: 'Utilities',
        accountId: 'Cash',
        dueDate: now.subtract(const Duration(days: 2)),
        createdAt: now,
      );

      final result = selectUpcomingAttention(
        upcomingBills: [overdueBill],
        upcomingPayments: [
          RecurringTransaction.create(
            id: 'r1',
            title: 'Netflix',
            amount: 499,
            categoryId: 'Entertainment',
            accountId: 'Cash',
            transactionType: 'expense',
            frequency: 'Monthly',
            startDate: now,
            createdAt: now,
          ),
        ],
        loanSummary: _emptyLoanSummary(),
        now: now,
      );

      expect(result, isNotNull);
      expect(result!.type, UpcomingAttentionType.overdueBill);
      expect(result.title, 'Electricity');
      expect(result.amount, 1200);
    });

    test('falls back to upcoming recurring payment when no bills need attention', () {
      final result = selectUpcomingAttention(
        upcomingBills: const [],
        upcomingPayments: [
          RecurringTransaction.create(
            id: 'r1',
            title: 'Netflix',
            amount: 499,
            categoryId: 'Entertainment',
            accountId: 'Cash',
            transactionType: 'expense',
            frequency: 'Monthly',
            startDate: now,
            createdAt: now,
          ),
        ],
        loanSummary: _emptyLoanSummary(),
        now: now,
      );

      expect(result, isNotNull);
      expect(result!.type, UpcomingAttentionType.recurringPayment);
      expect(result.title, 'Netflix');
    });

    test('falls back to the next EMI when nothing else needs attention', () {
      final loanSummary = LoanSummary(
        totalLoans: 1,
        activeLoans: 1,
        closedLoans: 0,
        outstandingBalance: 40000,
        totalEmiPerMonth: 5000,
        totalInterest: 3000,
        nextEmiLoanName: 'Car Loan',
        nextEmiAmount: 5000,
        nextEmiDate: now.add(const Duration(days: 4)),
      );

      final result = selectUpcomingAttention(
        upcomingBills: const [],
        upcomingPayments: const [],
        loanSummary: loanSummary,
        now: now,
      );

      expect(result, isNotNull);
      expect(result!.type, UpcomingAttentionType.loanEmi);
      expect(result.title, 'Car Loan');
      expect(result.amount, 5000);
    });

    test('returns null when nothing needs attention', () {
      final result = selectUpcomingAttention(
        upcomingBills: const [],
        upcomingPayments: const [],
        loanSummary: _emptyLoanSummary(),
        now: now,
      );
      expect(result, isNull);
    });
  });

  group('selectRelevantGoal', () {
    test('prefers the incomplete goal with the closest target date', () {
      final farGoal = Goal.create(
        id: 'g1',
        title: 'New Laptop',
        targetAmount: 80000,
        targetDate: now.add(const Duration(days: 200)),
        category: 'Electronics',
        icon: 'laptop',
        color: 0xFF000000,
        createdAt: now,
        currentAmount: 10000,
      );
      final nearGoal = Goal.create(
        id: 'g2',
        title: 'Goa Trip',
        targetAmount: 50000,
        targetDate: now.add(const Duration(days: 30)),
        category: 'Travel',
        icon: 'flight',
        color: 0xFF000000,
        createdAt: now,
        currentAmount: 25000,
      );

      final selected = selectRelevantGoal([farGoal, nearGoal]);
      expect(selected, isNotNull);
      expect(selected!.title, 'Goa Trip');
    });

    test('falls back to highest progress when every goal is complete', () {
      final completedLow = Goal.create(
        id: 'g1',
        title: 'Emergency Fund',
        targetAmount: 10000,
        targetDate: now.add(const Duration(days: 10)),
        category: 'Savings',
        icon: 'shield',
        color: 0xFF000000,
        createdAt: now,
        currentAmount: 10000,
      );
      final completedHigh = Goal.create(
        id: 'g2',
        title: 'Vacation',
        targetAmount: 5000,
        targetDate: now.add(const Duration(days: 20)),
        category: 'Travel',
        icon: 'flight',
        color: 0xFF000000,
        createdAt: now,
        currentAmount: 5000,
      );

      final selected = selectRelevantGoal([completedLow, completedHigh]);
      expect(selected, isNotNull);
      expect(selected!.isCompleted, isTrue);
    });

    test('returns null when there are no goals', () {
      expect(selectRelevantGoal(const []), isNull);
    });
  });
}
