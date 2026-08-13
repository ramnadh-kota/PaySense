import 'package:flutter_test/flutter_test.dart';
import 'package:paysense/shared/models/bill.dart';
import 'package:paysense/shared/models/cash_flow_event.dart';
import 'package:paysense/shared/models/loan.dart';
import 'package:paysense/shared/models/recurring_transaction.dart';
import 'package:paysense/shared/models/transaction.dart';
import 'package:paysense/shared/utils/cash_flow_calculator.dart';

Transaction _transaction({
  required String id,
  required double amount,
  required DateTime createdAt,
  String transactionType = 'expense',
}) => Transaction(
  id: id,
  title: id,
  amount: amount,
  categoryId: 'General',
  accountId: 'Cash',
  transactionType: transactionType,
  paymentMethod: 'manual',
  note: '',
  createdAt: createdAt,
);

Bill _bill({
  required String id,
  required double amount,
  required DateTime dueDate,
  bool isPaid = false,
}) => Bill(
  id: id,
  title: id,
  amount: amount,
  categoryId: 'Utilities',
  accountId: 'Cash',
  dueDate: dueDate,
  isPaid: isPaid,
  paidDate: null,
  isRecurring: false,
  frequency: 'Monthly',
  reminderDaysBefore: 2,
  note: '',
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

Loan _loan({
  required String id,
  required double emiAmount,
  required DateTime nextDueDate,
  String status = 'Active',
}) => Loan(
  id: id,
  loanName: id,
  lenderName: 'Bank',
  loanType: 'Personal',
  principalAmount: 100000,
  interestRate: 10,
  tenureMonths: 12,
  emiAmount: emiAmount,
  outstandingAmount: 50000,
  paidAmount: 50000,
  accountId: 'Checking',
  nextDueDate: nextDueDate,
  startDate: DateTime(2025, 1, 1),
  endDate: DateTime(2027, 1, 1),
  totalInterest: 5000,
  status: status,
  createdAt: DateTime(2025, 1, 1),
  updatedAt: DateTime(2025, 1, 1),
);

RecurringTransaction _recurring({
  required String id,
  required double amount,
  required DateTime nextDueDate,
  String transactionType = 'expense',
  bool isActive = true,
  DateTime? endDate,
}) => RecurringTransaction(
  id: id,
  title: id,
  amount: amount,
  categoryId: 'Subscriptions',
  accountId: 'Cash',
  transactionType: transactionType,
  frequency: 'Monthly',
  startDate: DateTime(2025, 1, 1),
  nextDueDate: nextDueDate,
  endDate: endDate,
  lastGeneratedDate: null,
  isActive: isActive,
  reminderDaysBefore: 1,
  note: '',
  createdAt: DateTime(2025, 1, 1),
  updatedAt: DateTime(2025, 1, 1),
);

void main() {
  final now = DateTime(2026, 8, 14);
  final month = DateTime(2026, 8, 1);

  group('CashFlowCalculator.eventsForMonth', () {
    test('1. income transaction becomes an income event', () {
      final events = CashFlowCalculator.eventsForMonth(
        transactions: [
          _transaction(id: 'Salary', amount: 50000, createdAt: DateTime(2026, 8, 1), transactionType: 'income'),
        ],
        bills: const [],
        loans: const [],
        recurringTransactions: const [],
        month: month,
        now: now,
      );

      expect(events, hasLength(1));
      expect(events.single.type, CashFlowEventType.income);
      expect(events.single.isInflow, isTrue);
      expect(events.single.isUpcoming, isFalse);
    });

    test('2. expense transaction becomes an expense event', () {
      final events = CashFlowCalculator.eventsForMonth(
        transactions: [
          _transaction(id: 'Groceries', amount: 2000, createdAt: DateTime(2026, 8, 14)),
        ],
        bills: const [],
        loans: const [],
        recurringTransactions: const [],
        month: month,
        now: now,
      );

      expect(events, hasLength(1));
      expect(events.single.type, CashFlowEventType.expense);
      expect(events.single.isInflow, isFalse);
    });

    test('3. upcoming (unpaid) bill appears', () {
      final events = CashFlowCalculator.eventsForMonth(
        transactions: const [],
        bills: [_bill(id: 'Rent', amount: 10000, dueDate: DateTime(2026, 8, 20))],
        loans: const [],
        recurringTransactions: const [],
        month: month,
        now: now,
      );

      expect(events, hasLength(1));
      expect(events.single.type, CashFlowEventType.bill);
      expect(events.single.isUpcoming, isTrue);
      expect(events.single.isOverdue, isFalse);
    });

    test('4. overdue bill appears on its original due date, not today', () {
      final overdueDate = DateTime(2026, 8, 5);
      final events = CashFlowCalculator.eventsForMonth(
        transactions: const [],
        bills: [_bill(id: 'Overdue Rent', amount: 10000, dueDate: overdueDate)],
        loans: const [],
        recurringTransactions: const [],
        month: month,
        now: now,
      );

      expect(events, hasLength(1));
      expect(events.single.date, overdueDate);
      expect(events.single.date, isNot(DateTime(now.year, now.month, now.day)));
      expect(events.single.isOverdue, isTrue);
    });

    test('5. a paid bill does not appear as an unpaid upcoming bill', () {
      final events = CashFlowCalculator.eventsForMonth(
        transactions: const [],
        bills: [_bill(id: 'Paid Rent', amount: 10000, dueDate: DateTime(2026, 8, 5), isPaid: true)],
        loans: const [],
        recurringTransactions: const [],
        month: month,
        now: now,
      );

      expect(events, isEmpty);
    });

    test('6. recurring payment (expense) appears', () {
      final events = CashFlowCalculator.eventsForMonth(
        transactions: const [],
        bills: const [],
        loans: const [],
        recurringTransactions: [
          _recurring(id: 'Netflix', amount: 649, nextDueDate: DateTime(2026, 8, 24)),
        ],
        month: month,
        now: now,
      );

      expect(events, hasLength(1));
      expect(events.single.type, CashFlowEventType.recurringPayment);
      expect(events.single.isInflow, isFalse);
    });

    test('7. recurring income appears when the model supports it', () {
      final events = CashFlowCalculator.eventsForMonth(
        transactions: const [],
        bills: const [],
        loans: const [],
        recurringTransactions: [
          _recurring(
            id: 'Salary',
            amount: 60000,
            nextDueDate: DateTime(2026, 8, 1),
            transactionType: 'income',
          ),
        ],
        month: month,
        now: now,
      );

      expect(events, hasLength(1));
      expect(events.single.type, CashFlowEventType.recurringIncome);
      expect(events.single.isInflow, isTrue);
    });

    test('8. loan EMI appears for an active loan', () {
      final events = CashFlowCalculator.eventsForMonth(
        transactions: const [],
        bills: const [],
        loans: [_loan(id: 'Car Loan', emiAmount: 8500, nextDueDate: DateTime(2026, 8, 18))],
        recurringTransactions: const [],
        month: month,
        now: now,
      );

      expect(events, hasLength(1));
      expect(events.single.type, CashFlowEventType.loanPayment);
      expect(events.single.isUpcoming, isTrue);
    });

    test('18. events outside the queried month are excluded', () {
      final events = CashFlowCalculator.eventsForMonth(
        transactions: [_transaction(id: 'July expense', amount: 500, createdAt: DateTime(2026, 7, 31))],
        bills: [_bill(id: 'September bill', amount: 1000, dueDate: DateTime(2026, 9, 1))],
        loans: const [],
        recurringTransactions: const [],
        month: month,
        now: now,
      );

      expect(events, isEmpty);
    });

    test('inactive/expired/closed items are excluded', () {
      final events = CashFlowCalculator.eventsForMonth(
        transactions: const [],
        bills: const [],
        loans: [_loan(id: 'Closed Loan', emiAmount: 5000, nextDueDate: DateTime(2026, 8, 10), status: 'Closed')],
        recurringTransactions: [
          _recurring(id: 'Cancelled', amount: 300, nextDueDate: DateTime(2026, 8, 10), isActive: false),
          _recurring(
            id: 'Expired',
            amount: 300,
            nextDueDate: DateTime(2026, 8, 10),
            endDate: DateTime(2026, 8, 1),
          ),
        ],
        month: month,
        now: now,
      );

      expect(events, isEmpty);
    });
  });

  group('CashFlowCalculator.groupByDate', () {
    test('9. events group correctly by date', () {
      final events = CashFlowCalculator.eventsForMonth(
        transactions: [_transaction(id: 'Groceries', amount: 2000, createdAt: DateTime(2026, 8, 5))],
        bills: [_bill(id: 'Rent', amount: 10000, dueDate: DateTime(2026, 8, 20))],
        loans: const [],
        recurringTransactions: const [],
        month: month,
        now: now,
      );

      final grouped = CashFlowCalculator.groupByDate(events);
      expect(grouped[DateTime(2026, 8, 5)], hasLength(1));
      expect(grouped[DateTime(2026, 8, 20)], hasLength(1));
      expect(grouped[DateTime(2026, 8, 6)], isNull);
    });

    test('10. multiple events on the same date are grouped together', () {
      final events = CashFlowCalculator.eventsForMonth(
        transactions: [_transaction(id: 'Coffee', amount: 200, createdAt: DateTime(2026, 8, 14))],
        bills: [_bill(id: 'Electricity', amount: 1500, dueDate: DateTime(2026, 8, 14))],
        loans: [_loan(id: 'Car Loan', emiAmount: 8500, nextDueDate: DateTime(2026, 8, 14))],
        recurringTransactions: const [],
        month: month,
        now: now,
      );

      final grouped = CashFlowCalculator.groupByDate(events);
      expect(grouped[DateTime(2026, 8, 14)], hasLength(3));
    });
  });

  group('CashFlowCalculator.summarizeMonth', () {
    test('11. monthly summary distinguishes recorded vs upcoming', () {
      final events = CashFlowCalculator.eventsForMonth(
        transactions: [
          _transaction(id: 'Salary', amount: 50000, createdAt: DateTime(2026, 8, 1), transactionType: 'income'),
          _transaction(id: 'Groceries', amount: 2000, createdAt: DateTime(2026, 8, 5)),
        ],
        bills: [_bill(id: 'Rent', amount: 10000, dueDate: DateTime(2026, 8, 20))],
        loans: const [],
        recurringTransactions: const [],
        month: month,
        now: now,
      );

      final summary = CashFlowCalculator.summarizeMonth(events);
      expect(summary.recordedIncome, 50000);
      expect(summary.recordedExpense, 2000);
      expect(summary.upcomingExpense, 10000);
      expect(summary.upcomingIncome, 0);
      expect(summary.expectedNet, 50000 - 2000 - 10000);
      expect(summary.hasActivity, isTrue);
    });

    test('12. an empty month reports no activity', () {
      final summary = CashFlowCalculator.summarizeMonth(const []);
      expect(summary.hasActivity, isFalse);
      expect(summary.expectedNet, 0);
    });
  });

  group('CashFlowCalculator.summarizeDay', () {
    test('13. an empty selected date has no events', () {
      final summary = CashFlowCalculator.summarizeDay(const []);
      expect(summary.hasEvents, isFalse);
      expect(summary.netExpectedMovement, 0);
      expect(summary.totalOutgoing, 0);
    });

    test('16. recorded vs upcoming distinction on a single day', () {
      final events = CashFlowCalculator.eventsForMonth(
        transactions: [
          _transaction(id: 'Salary', amount: 50000, createdAt: DateTime(2026, 8, 14), transactionType: 'income'),
          _transaction(id: 'Groceries', amount: 2000, createdAt: DateTime(2026, 8, 14)),
        ],
        bills: const [],
        loans: [_loan(id: 'Home Loan', emiAmount: 5000, nextDueDate: DateTime(2026, 8, 14))],
        recurringTransactions: const [],
        month: month,
        now: now,
      );
      final dayEvents = CashFlowCalculator.groupByDate(events)[DateTime(2026, 8, 14)]!;
      final summary = CashFlowCalculator.summarizeDay(dayEvents);

      expect(summary.recordedIncome, hasLength(1));
      expect(summary.recordedExpenses, hasLength(1));
      expect(summary.upcoming, hasLength(1));
      expect(summary.totalOutgoing, 2000 + 5000);
      expect(summary.netExpectedMovement, 50000 - 2000 - 5000);
    });
  });

  group('month navigation and today', () {
    test('14. adjacent months return disjoint event sets', () {
      final bill = _bill(id: 'Rent', amount: 10000, dueDate: DateTime(2026, 8, 20));

      final augustEvents = CashFlowCalculator.eventsForMonth(
        transactions: const [],
        bills: [bill],
        loans: const [],
        recurringTransactions: const [],
        month: DateTime(2026, 8, 1),
        now: now,
      );
      final septemberEvents = CashFlowCalculator.eventsForMonth(
        transactions: const [],
        bills: [bill],
        loans: const [],
        recurringTransactions: const [],
        month: DateTime(2026, 9, 1),
        now: now,
      );

      expect(augustEvents, hasLength(1));
      expect(septemberEvents, isEmpty);
    });

    test('15. a bill due exactly today is upcoming, not overdue', () {
      final events = CashFlowCalculator.eventsForMonth(
        transactions: const [],
        bills: [_bill(id: 'Due Today', amount: 999, dueDate: now)],
        loans: const [],
        recurringTransactions: const [],
        month: month,
        now: now,
      );

      expect(events.single.isUpcoming, isTrue);
      expect(events.single.isOverdue, isFalse);
      expect(events.single.date, DateTime(now.year, now.month, now.day));
    });
  });

  group('duplicate protection', () {
    test('17. a single active loan produces exactly one EMI event, not two', () {
      final events = CashFlowCalculator.eventsForMonth(
        transactions: const [],
        bills: const [],
        loans: [_loan(id: 'Car Loan', emiAmount: 8500, nextDueDate: DateTime(2026, 8, 18))],
        recurringTransactions: const [],
        month: month,
        now: now,
      );

      expect(events.where((e) => e.sourceId == 'Car Loan'), hasLength(1));
    });

    test('a recorded EMI transaction and the next scheduled EMI are shown as distinct events', () {
      // Mirrors the app's real behaviour: markEmiPaid() records a
      // Transaction AND advances Loan.nextDueDate forward, so the two can
      // never land on the same date for the same installment — but even if
      // they did coincide, they must remain two distinct, clearly-labelled
      // events rather than being silently merged.
      final events = CashFlowCalculator.eventsForMonth(
        transactions: [
          _transaction(id: 'Car Loan EMI', amount: 8500, createdAt: DateTime(2026, 8, 14)),
        ],
        bills: const [],
        loans: [_loan(id: 'Car Loan', emiAmount: 8500, nextDueDate: DateTime(2026, 8, 14))],
        recurringTransactions: const [],
        month: month,
        now: now,
      );

      expect(events, hasLength(2));
      expect(events.where((e) => e.isUpcoming), hasLength(1));
      expect(events.where((e) => !e.isUpcoming), hasLength(1));
    });
  });

  group('CashFlowCalculator.upcomingEvents', () {
    test('returns only upcoming/overdue items, soonest first, limited', () {
      final events = CashFlowCalculator.upcomingEvents(
        bills: [
          _bill(id: 'Later Bill', amount: 500, dueDate: DateTime(2026, 8, 28)),
          _bill(id: 'Sooner Bill', amount: 500, dueDate: DateTime(2026, 8, 16)),
        ],
        loans: const [],
        recurringTransactions: const [],
        now: now,
        limit: 1,
      );

      expect(events, hasLength(1));
      expect(events.single.sourceId, 'Sooner Bill');
    });
  });

  group('CashFlowCalculator.summarizeUpcomingWindow', () {
    test('excludes items beyond the window and includes overdue items', () {
      final summary = CashFlowCalculator.summarizeUpcomingWindow(
        bills: [
          _bill(id: 'Within window', amount: 1000, dueDate: now.add(const Duration(days: 10))),
          _bill(id: 'Outside window', amount: 5000, dueDate: now.add(const Duration(days: 40))),
          _bill(id: 'Overdue', amount: 200, dueDate: now.subtract(const Duration(days: 2))),
        ],
        loans: const [],
        recurringTransactions: const [],
        now: now,
        windowDays: 30,
      );

      expect(summary.upcomingExpense, 1000 + 200);
      expect(summary.hasActivity, isTrue);
    });
  });
}
