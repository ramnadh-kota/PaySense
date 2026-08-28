import 'package:flutter_test/flutter_test.dart';
import 'package:paysense/shared/models/bill.dart';
import 'package:paysense/shared/models/financial_safety_alert.dart';
import 'package:paysense/shared/models/loan.dart';
import 'package:paysense/shared/models/recurring_transaction.dart';
import 'package:paysense/shared/models/transaction.dart';
import 'package:paysense/shared/models/wallet.dart';
import 'package:paysense/shared/utils/financial_safety_engine.dart';

final _now = DateTime(2026, 8, 26);

Transaction _tx(String id, double amount, String type, DateTime date, {String title = 'Transaction'}) {
  return Transaction(
    id: id,
    title: title,
    amount: amount,
    categoryId: 'General',
    accountId: 'w1',
    transactionType: type,
    paymentMethod: 'card',
    note: '',
    createdAt: date,
  );
}

Wallet _wallet(double balance) => Wallet(
      id: 'w1',
      name: 'Main',
      bankName: 'Bank',
      type: 'bank',
      openingBalance: balance,
      currentBalance: balance,
      createdAt: _now,
    );

Bill _bill(double amount, DateTime dueDate, {bool isPaid = false}) => Bill(
      id: 'b1',
      title: 'Electricity',
      amount: amount,
      categoryId: 'Utilities',
      accountId: 'w1',
      dueDate: dueDate,
      isPaid: isPaid,
      isRecurring: false,
      frequency: 'Monthly',
      reminderDaysBefore: 1,
      note: '',
      createdAt: _now,
      updatedAt: _now,
    );

Loan _loan(double emi, DateTime nextDueDate) => Loan(
      id: 'l1',
      loanName: 'Car Loan',
      lenderName: 'Bank',
      loanType: 'Personal',
      principalAmount: 100000,
      interestRate: 10,
      tenureMonths: 24,
      emiAmount: emi,
      outstandingAmount: 50000,
      paidAmount: 50000,
      accountId: 'w1',
      nextDueDate: nextDueDate,
      startDate: DateTime(2025, 1, 1),
      endDate: DateTime(2027, 1, 1),
      totalInterest: 10000,
      status: 'Active',
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 1),
    );

void main() {
  group('1. Spending spike', () {
    test('flags when this month is 30%+ higher than the average of prior months', () {
      final transactions = [
        _tx('e1', 5000, 'expense', DateTime(2026, 5, 15)),
        _tx('e2', 5000, 'expense', DateTime(2026, 6, 15)),
        _tx('e3', 5000, 'expense', DateTime(2026, 7, 15)),
        _tx('e4', 8000, 'expense', DateTime(2026, 8, 5)),
      ];
      final alerts = FinancialSafetyEngine.generate(
        transactions: transactions,
        wallets: [_wallet(10000)],
        bills: const [],
        loans: const [],
        recurringTransactions: const [],
        now: _now,
      );
      expect(alerts.any((a) => a.type == FinancialSafetyAlertType.spendingSpike), isTrue);
    });

    test('does not flag normal, stable spending', () {
      final transactions = [
        _tx('e1', 5000, 'expense', DateTime(2026, 5, 15)),
        _tx('e2', 5000, 'expense', DateTime(2026, 6, 15)),
        _tx('e3', 5000, 'expense', DateTime(2026, 7, 15)),
        _tx('e4', 5100, 'expense', DateTime(2026, 8, 5)),
      ];
      final alerts = FinancialSafetyEngine.generate(
        transactions: transactions,
        wallets: [_wallet(10000)],
        bills: const [],
        loans: const [],
        recurringTransactions: const [],
        now: _now,
      );
      expect(alerts.any((a) => a.type == FinancialSafetyAlertType.spendingSpike), isFalse);
    });
  });

  group('2. Low balance risk', () {
    test('flags when upcoming bills+EMIs exceed current balance', () {
      final alerts = FinancialSafetyEngine.generate(
        transactions: const [],
        wallets: [_wallet(1000)],
        bills: [_bill(2000, _now.add(const Duration(days: 3)))],
        loans: const [],
        recurringTransactions: const [],
        now: _now,
      );
      expect(alerts.any((a) => a.type == FinancialSafetyAlertType.lowBalanceRisk), isTrue);
    });

    test('does not flag when balance comfortably covers upcoming outflow', () {
      final alerts = FinancialSafetyEngine.generate(
        transactions: const [],
        wallets: [_wallet(50000)],
        bills: [_bill(2000, _now.add(const Duration(days: 3)))],
        loans: const [],
        recurringTransactions: const [],
        now: _now,
      );
      expect(alerts.any((a) => a.type == FinancialSafetyAlertType.lowBalanceRisk), isFalse);
    });

    test('a paid bill never contributes to upcoming outflow', () {
      final alerts = FinancialSafetyEngine.generate(
        transactions: const [],
        wallets: [_wallet(500)],
        bills: [_bill(2000, _now.add(const Duration(days: 3)), isPaid: true)],
        loans: const [],
        recurringTransactions: const [],
        now: _now,
      );
      expect(alerts.any((a) => a.type == FinancialSafetyAlertType.lowBalanceRisk), isFalse);
    });
  });

  group('3. Upcoming EMI pressure', () {
    test('flags an EMI due within the horizon', () {
      final alerts = FinancialSafetyEngine.generate(
        transactions: const [],
        wallets: [_wallet(100000)],
        bills: const [],
        loans: [_loan(14500, _now.add(const Duration(days: 2)))],
        recurringTransactions: const [],
        now: _now,
      );
      expect(alerts.any((a) => a.type == FinancialSafetyAlertType.upcomingEmiPressure), isTrue);
    });

    test('does not flag an EMI far in the future', () {
      final alerts = FinancialSafetyEngine.generate(
        transactions: const [],
        wallets: [_wallet(100000)],
        bills: const [],
        loans: [_loan(14500, _now.add(const Duration(days: 60)))],
        recurringTransactions: const [],
        now: _now,
      );
      expect(alerts.any((a) => a.type == FinancialSafetyAlertType.upcomingEmiPressure), isFalse);
    });
  });

  group('4. Recurring payment pressure', () {
    test('flags when recurring commitments exceed 50% of average income', () {
      final recurring = RecurringTransaction(
        id: 'r1', title: 'Subscription', amount: 5000, categoryId: 'Subscriptions', accountId: 'w1',
        transactionType: 'expense', frequency: 'Monthly', startDate: DateTime(2026, 1, 1),
        nextDueDate: DateTime(2026, 9, 1), isActive: true, reminderDaysBefore: 1, note: '',
        createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1),
      );
      final income = [
        _tx('i1', 8000, 'income', DateTime(2026, 6, 1)),
        _tx('i2', 8000, 'income', DateTime(2026, 7, 1)),
        _tx('i3', 8000, 'income', DateTime(2026, 8, 1)),
      ];
      final alerts = FinancialSafetyEngine.generate(
        transactions: income,
        wallets: [_wallet(10000)],
        bills: const [],
        loans: const [],
        recurringTransactions: [recurring],
        now: _now,
      );
      expect(alerts.any((a) => a.type == FinancialSafetyAlertType.recurringPaymentPressure), isTrue);
    });
  });

  group('5. Salary irregularity', () {
    test('flags when expected recurring income never arrived within the grace window', () {
      final recurringIncome = RecurringTransaction(
        id: 'r1', title: 'Salary', amount: 70000, categoryId: 'Income', accountId: 'w1',
        transactionType: 'income', frequency: 'Monthly', startDate: DateTime(2026, 1, 1),
        nextDueDate: DateTime(2026, 8, 1), isActive: true, reminderDaysBefore: 1, note: '',
        createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1),
      );
      final alerts = FinancialSafetyEngine.generate(
        transactions: const [], // no matching income transaction at all
        wallets: [_wallet(10000)],
        bills: const [],
        loans: const [],
        recurringTransactions: [recurringIncome],
        now: _now,
      );
      expect(alerts.any((a) => a.type == FinancialSafetyAlertType.salaryIrregularity), isTrue);
    });

    test('does not flag when the salary arrived on time and at the expected amount', () {
      final recurringIncome = RecurringTransaction(
        id: 'r1', title: 'Salary', amount: 70000, categoryId: 'Income', accountId: 'w1',
        transactionType: 'income', frequency: 'Monthly', startDate: DateTime(2026, 1, 1),
        nextDueDate: DateTime(2026, 8, 1), isActive: true, reminderDaysBefore: 1, note: '',
        createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1),
      );
      final alerts = FinancialSafetyEngine.generate(
        transactions: [_tx('i1', 70000, 'income', DateTime(2026, 8, 1))],
        wallets: [_wallet(10000)],
        bills: const [],
        loans: const [],
        recurringTransactions: [recurringIncome],
        now: _now,
      );
      expect(alerts.any((a) => a.type == FinancialSafetyAlertType.salaryIrregularity), isFalse);
    });
  });

  group('6. Large unusual transaction', () {
    test('flags a transaction far above the recent median', () {
      final transactions = [
        for (var i = 0; i < 5; i++) _tx('e$i', 500, 'expense', _now.subtract(Duration(days: i * 10))),
        _tx('big', 5000, 'expense', _now, title: 'Big Purchase'),
      ];
      final alerts = FinancialSafetyEngine.generate(
        transactions: transactions,
        wallets: [_wallet(10000)],
        bills: const [],
        loans: const [],
        recurringTransactions: const [],
        now: _now,
      );
      expect(alerts.any((a) => a.type == FinancialSafetyAlertType.largeUnusualTransaction), isTrue);
    });

    test('does not flag when there is too little history to establish a baseline', () {
      final transactions = [_tx('e1', 500, 'expense', _now), _tx('e2', 5000, 'expense', _now)];
      final alerts = FinancialSafetyEngine.generate(
        transactions: transactions,
        wallets: [_wallet(10000)],
        bills: const [],
        loans: const [],
        recurringTransactions: const [],
        now: _now,
      );
      expect(alerts.any((a) => a.type == FinancialSafetyAlertType.largeUnusualTransaction), isFalse);
    });
  });

  group('7. Cash-flow deficit', () {
    test('flags when this month\'s expense exceeds this month\'s income', () {
      final alerts = FinancialSafetyEngine.generate(
        transactions: [
          _tx('i1', 5000, 'income', DateTime(2026, 8, 1)),
          _tx('e1', 8000, 'expense', DateTime(2026, 8, 10)),
        ],
        wallets: [_wallet(10000)],
        bills: const [],
        loans: const [],
        recurringTransactions: const [],
        now: _now,
      );
      expect(alerts.any((a) => a.type == FinancialSafetyAlertType.cashFlowDeficit), isTrue);
    });

    test('does not flag a healthy surplus month', () {
      final alerts = FinancialSafetyEngine.generate(
        transactions: [
          _tx('i1', 50000, 'income', DateTime(2026, 8, 1)),
          _tx('e1', 8000, 'expense', DateTime(2026, 8, 10)),
        ],
        wallets: [_wallet(10000)],
        bills: const [],
        loans: const [],
        recurringTransactions: const [],
        now: _now,
      );
      expect(alerts.any((a) => a.type == FinancialSafetyAlertType.cashFlowDeficit), isFalse);
    });
  });

  group('8. Multiple large transactions close together', () {
    test('flags 3+ large transactions within a short window', () {
      final transactions = [
        _tx('e1', 6000, 'expense', _now),
        _tx('e2', 7000, 'expense', _now.add(const Duration(days: 1))),
        _tx('e3', 8000, 'expense', _now.add(const Duration(days: 2))),
      ];
      final alerts = FinancialSafetyEngine.generate(
        transactions: transactions,
        wallets: [_wallet(100000)],
        bills: const [],
        loans: const [],
        recurringTransactions: const [],
        now: _now,
      );
      expect(alerts.any((a) => a.type == FinancialSafetyAlertType.multipleLargeTransactionsCluster), isTrue);
    });

    test('does not flag isolated large transactions spread far apart', () {
      final transactions = [
        _tx('e1', 6000, 'expense', _now),
        _tx('e2', 7000, 'expense', _now.add(const Duration(days: 20))),
        _tx('e3', 8000, 'expense', _now.add(const Duration(days: 40))),
      ];
      final alerts = FinancialSafetyEngine.generate(
        transactions: transactions,
        wallets: [_wallet(100000)],
        bills: const [],
        loans: const [],
        recurringTransactions: const [],
        now: _now,
      );
      expect(alerts.any((a) => a.type == FinancialSafetyAlertType.multipleLargeTransactionsCluster), isFalse);
    });
  });

  test('no data at all produces zero alerts, never crashes', () {
    final alerts = FinancialSafetyEngine.generate(
      transactions: const [],
      wallets: const [],
      bills: const [],
      loans: const [],
      recurringTransactions: const [],
      now: _now,
    );
    expect(alerts, isEmpty);
  });

  test('every alert uses "PaySense insight" framing, never directive/fear-based language', () {
    final alerts = FinancialSafetyEngine.generate(
      transactions: [
        _tx('i1', 5000, 'income', DateTime(2026, 8, 1)),
        _tx('e1', 8000, 'expense', DateTime(2026, 8, 10)),
      ],
      wallets: [_wallet(100)],
      bills: [_bill(2000, _now.add(const Duration(days: 3)))],
      loans: const [],
      recurringTransactions: const [],
      now: _now,
    );
    expect(alerts, isNotEmpty);
    for (final alert in alerts) {
      expect(alert.title, contains('PaySense insight'));
      expect(alert.recommendedAction.toLowerCase(), isNot(contains('should invest')));
    }
  });
}
