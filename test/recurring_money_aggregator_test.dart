import 'package:flutter_test/flutter_test.dart';
import 'package:paysense/shared/models/bill.dart';
import 'package:paysense/shared/models/loan.dart';
import 'package:paysense/shared/models/recurring_transaction.dart';
import 'package:paysense/shared/utils/financial_action_engine.dart';
import 'package:paysense/shared/utils/recurring_money_aggregator.dart';

final _now = DateTime(2026, 8, 26);

RecurringTransaction _recurring({
  required String id,
  required String title,
  required double amount,
  required String frequency,
  DateTime? createdAt,
  DateTime? nextDueDate,
  bool isActive = true,
}) {
  return RecurringTransaction(
    id: id,
    title: title,
    amount: amount,
    categoryId: 'Subscriptions',
    accountId: 'w1',
    transactionType: 'expense',
    frequency: frequency,
    startDate: createdAt ?? DateTime(2026, 1, 1),
    nextDueDate: nextDueDate ?? DateTime(2026, 9, 1),
    isActive: isActive,
    reminderDaysBefore: 1,
    note: '',
    createdAt: createdAt ?? DateTime(2026, 1, 1),
    updatedAt: createdAt ?? DateTime(2026, 1, 1),
  );
}

Bill _bill({
  required String id,
  required String title,
  required double amount,
  bool isRecurring = true,
  String frequency = 'Monthly',
  DateTime? createdAt,
  DateTime? dueDate,
}) {
  return Bill(
    id: id,
    title: title,
    amount: amount,
    categoryId: 'Utilities',
    accountId: 'w1',
    dueDate: dueDate ?? DateTime(2026, 9, 5),
    isPaid: false,
    isRecurring: isRecurring,
    frequency: frequency,
    reminderDaysBefore: 1,
    note: '',
    createdAt: createdAt ?? DateTime(2026, 1, 1),
    updatedAt: createdAt ?? DateTime(2026, 1, 1),
  );
}

Loan _loan({required String id, required String name, required double emi, bool active = true}) {
  return Loan(
    id: id,
    loanName: name,
    lenderName: 'Test Bank',
    loanType: 'Personal',
    principalAmount: 100000,
    interestRate: 10,
    tenureMonths: 24,
    emiAmount: emi,
    outstandingAmount: 50000,
    paidAmount: 50000,
    accountId: 'w1',
    nextDueDate: DateTime(2026, 9, 5),
    startDate: DateTime(2025, 1, 1),
    endDate: DateTime(2027, 1, 1),
    totalInterest: 10000,
    status: active ? 'Active' : 'Closed',
    createdAt: DateTime(2025, 1, 1),
    updatedAt: DateTime(2025, 1, 1),
  );
}

void main() {
  group('RecurringMoneyAggregator.summarize', () {
    test('a monthly subscription contributes its own amount as the monthly equivalent', () {
      final summary = RecurringMoneyAggregator.summarize(
        recurringTransactions: [_recurring(id: 'r1', title: 'Netflix', amount: 649, frequency: 'Monthly')],
        bills: const [],
        loans: const [],
        now: _now,
      );
      expect(summary.subscriptions.single.monthlyEquivalent, 649);
      expect(summary.totalMonthlyCost, 649);
    });

    test('a yearly subscription is converted to its monthly equivalent, never shown at face value', () {
      final summary = RecurringMoneyAggregator.summarize(
        recurringTransactions: [_recurring(id: 'r1', title: 'Amazon Prime', amount: 1499, frequency: 'Yearly')],
        bills: const [],
        loans: const [],
        now: _now,
      );
      expect(summary.subscriptions.single.monthlyEquivalent, closeTo(1499 / 12, 0.01));
    });

    test('a weekly subscription is converted correctly too', () {
      final summary = RecurringMoneyAggregator.summarize(
        recurringTransactions: [_recurring(id: 'r1', title: 'Weekly Meal Kit', amount: 500, frequency: 'Weekly')],
        bills: const [],
        loans: const [],
        now: _now,
      );
      expect(summary.subscriptions.single.monthlyEquivalent, closeTo(500 * 52 / 12, 0.01));
    });

    test('recurring bills are counted separately from subscriptions', () {
      final summary = RecurringMoneyAggregator.summarize(
        recurringTransactions: const [],
        bills: [_bill(id: 'b1', title: 'Electricity', amount: 2340)],
        loans: const [],
        now: _now,
      );
      expect(summary.recurringBills.single.title, 'Electricity');
      expect(summary.subscriptions, isEmpty);
      expect(summary.totalMonthlyCost, 2340);
    });

    test('a non-recurring bill is excluded from the Bills section', () {
      final summary = RecurringMoneyAggregator.summarize(
        recurringTransactions: const [],
        bills: [_bill(id: 'b1', title: 'One-off repair', amount: 5000, isRecurring: false)],
        loans: const [],
        now: _now,
      );
      expect(summary.recurringBills, isEmpty);
    });

    test('active loan EMIs are counted with their real EMI amount', () {
      final summary = RecurringMoneyAggregator.summarize(
        recurringTransactions: const [],
        bills: const [],
        loans: [_loan(id: 'l1', name: 'Car Loan', emi: 14500)],
        now: _now,
      );
      expect(summary.emiLoans.single.loanName, 'Car Loan');
      expect(summary.totalMonthlyCost, 14500);
    });

    test('a closed loan is excluded from EMIs', () {
      final summary = RecurringMoneyAggregator.summarize(
        recurringTransactions: const [],
        bills: const [],
        loans: [_loan(id: 'l1', name: 'Old Loan', emi: 5000, active: false)],
        now: _now,
      );
      expect(summary.emiLoans, isEmpty);
    });

    test('total monthly/annual cost sums across all three sections', () {
      final summary = RecurringMoneyAggregator.summarize(
        recurringTransactions: [_recurring(id: 'r1', title: 'Netflix', amount: 649, frequency: 'Monthly')],
        bills: [_bill(id: 'b1', title: 'Electricity', amount: 2340)],
        loans: [_loan(id: 'l1', name: 'Car Loan', emi: 14500)],
        now: _now,
      );
      const expectedMonthly = 649 + 2340.0 + 14500;
      expect(summary.totalMonthlyCost, expectedMonthly);
      expect(summary.totalAnnualCost, expectedMonthly * 12);
      expect(summary.totalCommitmentCount, 3);
    });

    test('"you have N recurring commitments" insight is generated', () {
      final summary = RecurringMoneyAggregator.summarize(
        recurringTransactions: [_recurring(id: 'r1', title: 'Netflix', amount: 649, frequency: 'Monthly')],
        bills: [_bill(id: 'b1', title: 'Electricity', amount: 2340)],
        loans: const [],
        now: _now,
      );
      expect(summary.insights, contains('You have 2 recurring commitments.'));
    });

    test('a recently-created material bill is flagged as a new recurring payment', () {
      final summary = RecurringMoneyAggregator.summarize(
        recurringTransactions: const [],
        bills: [_bill(id: 'b1', title: 'New Gym Membership', amount: 2499, createdAt: _now.subtract(const Duration(days: 5)))],
        loans: const [],
        now: _now,
      );
      expect(summary.insights.any((i) => i.contains('New Gym Membership') && i.contains('new recurring payment')), isTrue);
    });

    test('a recently-created but IMMATERIAL bill is never flagged as new (reuses FinancialActionEngine\'s threshold)', () {
      final summary = RecurringMoneyAggregator.summarize(
        recurringTransactions: const [],
        bills: [_bill(id: 'b1', title: 'Tiny fee', amount: 50, createdAt: _now.subtract(const Duration(days: 5)))],
        loans: const [],
        now: _now,
      );
      expect(50 < FinancialActionEngine.subscriptionMaterialityThreshold, isTrue);
      expect(summary.insights.any((i) => i.contains('Tiny fee')), isFalse);
    });

    test('an old material bill (created long ago) is never flagged as new', () {
      final summary = RecurringMoneyAggregator.summarize(
        recurringTransactions: const [],
        bills: [_bill(id: 'b1', title: 'Old Rent', amount: 18000, createdAt: DateTime(2020, 1, 1))],
        loans: const [],
        now: _now,
      );
      expect(summary.insights.any((i) => i.contains('Old Rent')), isFalse);
    });

    test('no data at all produces an empty, non-crashing summary', () {
      final summary = RecurringMoneyAggregator.summarize(
        recurringTransactions: const [],
        bills: const [],
        loans: const [],
        now: _now,
      );
      expect(summary.isEmpty, isTrue);
      expect(summary.totalMonthlyCost, 0);
      expect(summary.insights, isEmpty);
    });

    test('an inactive recurring transaction is excluded (never silently included)', () {
      final summary = RecurringMoneyAggregator.summarize(
        recurringTransactions: [_recurring(id: 'r1', title: 'Cancelled Sub', amount: 500, frequency: 'Monthly', isActive: false)],
        bills: const [],
        loans: const [],
        now: _now,
      );
      expect(summary.subscriptions, isEmpty);
    });
  });
}
