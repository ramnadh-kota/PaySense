// FINANCIAL SAFETY ENGINE — PHASE R privacy audit. Confirms alerts (and
// the AI-context map built from them) never carry a forbidden fragment,
// following the exact recursive-scan convention established in
// test/transaction_ingestion_privacy_test.dart and
// test/account_aggregator_privacy_test.dart.
import 'package:flutter_test/flutter_test.dart';
import 'package:paysense/shared/models/bill.dart';
import 'package:paysense/shared/models/loan.dart';
import 'package:paysense/shared/models/transaction.dart';
import 'package:paysense/shared/models/wallet.dart';
import 'package:paysense/shared/utils/financial_safety_engine.dart';

const _forbiddenFragments = [
  'password', 'passwd', 'pin', 'otp', 'cvv', 'cvc', 'cardnumber', 'card_number',
  'secret', 'token', 'credential', 'smsbody', 'phonenumber',
];

String _normalize(String raw) => raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

void _assertNoForbiddenFragment(String value, String label) {
  final normalized = _normalize(value);
  for (final fragment in _forbiddenFragments) {
    expect(normalized.contains(fragment), isFalse, reason: 'forbidden fragment "$fragment" found in $label: "$value"');
  }
}

void main() {
  final now = DateTime(2026, 8, 26);

  test('every alert field is free of forbidden fragments across all trigger scenarios', () {
    final alerts = FinancialSafetyEngine.generate(
      transactions: [
        Transaction(id: 't1', title: 'Salary', amount: 5000, categoryId: 'Income', accountId: 'w1', transactionType: 'income', paymentMethod: 'card', note: '', createdAt: DateTime(2026, 8, 1)),
        Transaction(id: 't2', title: 'Large Purchase', amount: 20000, categoryId: 'Shopping', accountId: 'w1', transactionType: 'expense', paymentMethod: 'card', note: '', createdAt: DateTime(2026, 8, 10)),
      ],
      wallets: [Wallet(id: 'w1', name: 'Main', bankName: 'Bank', type: 'bank', openingBalance: 100, currentBalance: 100, createdAt: now)],
      bills: [
        Bill(id: 'b1', title: 'Electricity', amount: 2000, categoryId: 'Utilities', accountId: 'w1', dueDate: now.add(const Duration(days: 2)), isPaid: false, isRecurring: false, frequency: 'Monthly', reminderDaysBefore: 1, note: '', createdAt: now, updatedAt: now),
      ],
      loans: [
        Loan(id: 'l1', loanName: 'Car Loan', lenderName: 'Bank', loanType: 'Personal', principalAmount: 100000, interestRate: 10, tenureMonths: 24, emiAmount: 14500, outstandingAmount: 50000, paidAmount: 50000, accountId: 'w1', nextDueDate: now.add(const Duration(days: 2)), startDate: DateTime(2025, 1, 1), endDate: DateTime(2027, 1, 1), totalInterest: 10000, status: 'Active', createdAt: DateTime(2025, 1, 1), updatedAt: DateTime(2025, 1, 1)),
      ],
      recurringTransactions: const [],
      now: now,
    );

    expect(alerts, isNotEmpty);
    for (final alert in alerts) {
      _assertNoForbiddenFragment(alert.title, 'title');
      _assertNoForbiddenFragment(alert.explanation, 'explanation');
      _assertNoForbiddenFragment(alert.recommendedAction, 'recommendedAction');
      _assertNoForbiddenFragment(alert.type.name, 'type');
      _assertNoForbiddenFragment(alert.id, 'id');
    }
  });
}
