import 'package:flutter_test/flutter_test.dart';
import 'package:paysense/shared/models/bill.dart';
import 'package:paysense/shared/models/loan.dart';
import 'package:paysense/shared/models/recurring_transaction.dart';
import 'package:paysense/shared/models/wallet.dart';
import 'package:paysense/shared/utils/safe_to_spend_calculator.dart';

Wallet _wallet(String id, double balance) => Wallet(
  id: id,
  name: id,
  bankName: '',
  type: 'cash',
  openingBalance: balance,
  currentBalance: balance,
  createdAt: DateTime(2026, 1, 1),
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
  final now = DateTime(2026, 6, 15);

  group('SafeToSpendCalculator', () {
    test('1. normal positive Safe-to-Spend', () {
      final result = SafeToSpendCalculator.calculate(
        wallets: [_wallet('w1', 50000)],
        bills: [_bill(id: 'Rent', amount: 10000, dueDate: now.add(const Duration(days: 5)))],
        loans: const [],
        recurringTransactions: const [],
        now: now,
      );

      expect(result.hasSufficientData, isTrue);
      expect(result.availableMoney, 50000);
      expect(result.upcomingCommitments, 10000);
      expect(result.safeToSpend, 40000);
      expect(result.shortfall, 0);
      expect(result.isShortfall, isFalse);
    });

    test('2. no upcoming commitments', () {
      final result = SafeToSpendCalculator.calculate(
        wallets: [_wallet('w1', 20000)],
        bills: const [],
        loans: const [],
        recurringTransactions: const [],
        now: now,
      );

      expect(result.commitmentBreakdown, isEmpty);
      expect(result.upcomingCommitments, 0);
      expect(result.safeToSpend, 20000);
    });

    test('3. commitments exceed available money', () {
      final result = SafeToSpendCalculator.calculate(
        wallets: [_wallet('w1', 5000)],
        bills: [_bill(id: 'Rent', amount: 9250, dueDate: now.add(const Duration(days: 2)))],
        loans: const [],
        recurringTransactions: const [],
        now: now,
      );

      expect(result.safeToSpend, 0);
      expect(result.isShortfall, isTrue);
      expect(result.shortfall, 4250);
    });

    test('4. bills included in the breakdown', () {
      final result = SafeToSpendCalculator.calculate(
        wallets: [_wallet('w1', 100000)],
        bills: [_bill(id: 'Internet', amount: 999, dueDate: now.add(const Duration(days: 3)))],
        loans: const [],
        recurringTransactions: const [],
        now: now,
      );

      expect(result.commitmentBreakdown, hasLength(1));
      expect(result.commitmentBreakdown.single.type, SafeToSpendCommitmentType.bill);
      expect(result.commitmentBreakdown.single.amount, 999);
    });

    test('5. EMI included in the breakdown', () {
      final result = SafeToSpendCalculator.calculate(
        wallets: [_wallet('w1', 100000)],
        bills: const [],
        loans: [_loan(id: 'Car Loan', emiAmount: 8500, nextDueDate: now.add(const Duration(days: 10)))],
        recurringTransactions: const [],
        now: now,
      );

      expect(result.commitmentBreakdown, hasLength(1));
      expect(result.commitmentBreakdown.single.type, SafeToSpendCommitmentType.emi);
      expect(result.commitmentBreakdown.single.amount, 8500);
    });

    test('6. recurring payments included in the breakdown', () {
      final result = SafeToSpendCalculator.calculate(
        wallets: [_wallet('w1', 100000)],
        bills: const [],
        loans: const [],
        recurringTransactions: [
          _recurring(id: 'Netflix', amount: 649, nextDueDate: now.add(const Duration(days: 4))),
        ],
        now: now,
      );

      expect(result.commitmentBreakdown, hasLength(1));
      expect(result.commitmentBreakdown.single.type, SafeToSpendCommitmentType.recurring);
    });

    test('6b. income-type recurring items are excluded (not a commitment)', () {
      final result = SafeToSpendCalculator.calculate(
        wallets: [_wallet('w1', 100000)],
        bills: const [],
        loans: const [],
        recurringTransactions: [
          _recurring(
            id: 'Salary',
            amount: 60000,
            nextDueDate: now.add(const Duration(days: 4)),
            transactionType: 'income',
          ),
        ],
        now: now,
      );

      expect(result.commitmentBreakdown, isEmpty);
    });

    test('7. savings contribution is never fabricated when "available"', () {
      // The Goal model has no planned/monthly-contribution field, so even
      // with active goals present, a v1 calculator must not invent one.
      final result = SafeToSpendCalculator.calculate(
        wallets: [_wallet('w1', 50000)],
        bills: const [],
        loans: const [],
        recurringTransactions: const [],
        now: now,
      );

      expect(result.savingsIncluded, isFalse);
      expect(result.plannedSavings, 0);
    });

    test('8. no savings contribution when unavailable', () {
      final result = SafeToSpendCalculator.calculate(
        wallets: [_wallet('w1', 50000)],
        bills: const [],
        loans: const [],
        recurringTransactions: const [],
        now: now,
      );

      expect(result.savingsIncluded, isFalse);
      expect(result.plannedSavings, 0);
      expect(result.safeToSpend, 50000);
    });

    test('9. daily Safe-to-Spend calculation', () {
      final result = SafeToSpendCalculator.calculate(
        wallets: [_wallet('w1', 12000)],
        bills: const [],
        loans: const [],
        recurringTransactions: const [],
        now: now,
        windowDays: 30,
      );

      expect(result.safeToSpend, 12000);
      expect(result.dailySafeToSpend, closeTo(400, 0.001));
    });

    test('10. zero remaining days does not crash or divide by zero', () {
      final result = SafeToSpendCalculator.calculate(
        wallets: [_wallet('w1', 12000)],
        bills: const [],
        loans: const [],
        recurringTransactions: const [],
        now: now,
        windowDays: 0,
      );

      expect(result.remainingDays, 0);
      expect(result.dailySafeToSpend, 0);
    });

    test('11. no wallet data', () {
      final result = SafeToSpendCalculator.calculate(
        wallets: const [],
        bills: [_bill(id: 'Rent', amount: 10000, dueDate: now)],
        loans: const [],
        recurringTransactions: const [],
        now: now,
      );

      expect(result.hasSufficientData, isFalse);
      expect(result.availableMoney, 0);
      expect(result.safeToSpend, 0);
      expect(result.commitmentBreakdown, isEmpty);
    });

    test('12. multiple wallets are summed', () {
      final result = SafeToSpendCalculator.calculate(
        wallets: [_wallet('cash', 5000), _wallet('bank', 45000)],
        bills: const [],
        loans: const [],
        recurringTransactions: const [],
        now: now,
      );

      expect(result.availableMoney, 50000);
    });

    test('13. multiple commitments across all three sources', () {
      final result = SafeToSpendCalculator.calculate(
        wallets: [_wallet('w1', 100000)],
        bills: [
          _bill(id: 'Rent', amount: 10000, dueDate: now.add(const Duration(days: 2))),
          _bill(id: 'Electricity', amount: 1500, dueDate: now.add(const Duration(days: 6))),
        ],
        loans: [_loan(id: 'Car Loan', emiAmount: 8500, nextDueDate: now.add(const Duration(days: 9)))],
        recurringTransactions: [
          _recurring(id: 'Netflix', amount: 649, nextDueDate: now.add(const Duration(days: 4))),
        ],
        now: now,
      );

      expect(result.commitmentBreakdown, hasLength(4));
      expect(result.upcomingCommitments, 10000 + 1500 + 8500 + 649);
      expect(
        result.commitmentBreakdown.map((c) => c.dueDate.day),
        orderedEquals(result.commitmentBreakdown.map((c) => c.dueDate.day).toList()..sort()),
      );
    });

    test('14. an overdue-and-unpaid bill is counted exactly once, not duplicated', () {
      final overdueBill = _bill(
        id: 'Overdue Rent',
        amount: 10000,
        dueDate: now.subtract(const Duration(days: 3)),
      );
      // isOverdue and isUpcoming are mutually exclusive on Bill itself;
      // this asserts the calculator doesn't independently re-add the same
      // bill via a second code path.
      expect(overdueBill.isOverdue(now), isTrue);
      expect(overdueBill.isUpcoming(now, days: 30), isFalse);

      final result = SafeToSpendCalculator.calculate(
        wallets: [_wallet('w1', 100000)],
        bills: [overdueBill],
        loans: const [],
        recurringTransactions: const [],
        now: now,
      );

      expect(result.commitmentBreakdown, hasLength(1));
      expect(result.commitmentBreakdown.single.isOverdue, isTrue);
    });

    test('15. empty financial data (wallet present, nothing else)', () {
      final result = SafeToSpendCalculator.calculate(
        wallets: [_wallet('w1', 0)],
        bills: const [],
        loans: const [],
        recurringTransactions: const [],
        now: now,
      );

      expect(result.hasSufficientData, isTrue);
      expect(result.availableMoney, 0);
      expect(result.upcomingCommitments, 0);
      expect(result.safeToSpend, 0);
      expect(result.isShortfall, isFalse);
      expect(result.dailySafeToSpend, 0);
    });

    test('commitments outside the 30-day window are excluded', () {
      final result = SafeToSpendCalculator.calculate(
        wallets: [_wallet('w1', 100000)],
        bills: [_bill(id: 'Annual Insurance', amount: 20000, dueDate: now.add(const Duration(days: 45)))],
        loans: [_loan(id: 'Home Loan', emiAmount: 15000, nextDueDate: now.add(const Duration(days: 60)))],
        recurringTransactions: [
          _recurring(id: 'Far Future', amount: 500, nextDueDate: now.add(const Duration(days: 90))),
        ],
        now: now,
      );

      expect(result.commitmentBreakdown, isEmpty);
      expect(result.safeToSpend, 100000);
    });

    test('inactive/expired/closed items are excluded', () {
      final result = SafeToSpendCalculator.calculate(
        wallets: [_wallet('w1', 100000)],
        bills: const [],
        loans: [_loan(id: 'Paid Off', emiAmount: 5000, nextDueDate: now.add(const Duration(days: 5)), status: 'Closed')],
        recurringTransactions: [
          _recurring(id: 'Cancelled', amount: 300, nextDueDate: now.add(const Duration(days: 5)), isActive: false),
          _recurring(
            id: 'Expired',
            amount: 300,
            nextDueDate: now.add(const Duration(days: 5)),
            endDate: now.subtract(const Duration(days: 1)),
          ),
        ],
        now: now,
      );

      expect(result.commitmentBreakdown, isEmpty);
    });
  });
}
