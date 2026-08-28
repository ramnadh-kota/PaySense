import 'package:flutter_test/flutter_test.dart';
import 'package:paysense/core/routes/app_routes.dart';
import 'package:paysense/shared/models/bill.dart';
import 'package:paysense/shared/models/financial_search_result.dart';
import 'package:paysense/shared/models/loan.dart';
import 'package:paysense/shared/models/recurring_transaction.dart';
import 'package:paysense/shared/models/transaction.dart';
import 'package:paysense/shared/models/wallet.dart';
import 'package:paysense/shared/utils/financial_search_engine.dart';
import 'package:paysense/shared/utils/safe_to_spend_calculator.dart';

final _now = DateTime(2026, 8, 26);

Transaction _tx(String id, String title, double amount, String type, DateTime date, {String category = 'General', String accountId = 'w1'}) {
  return Transaction(id: id, title: title, amount: amount, categoryId: category, accountId: accountId, transactionType: type, paymentMethod: 'card', note: '', createdAt: date);
}

Wallet _wallet(String id, String name, double balance, {String bankName = ''}) =>
    Wallet(id: id, name: name, bankName: bankName, type: 'bank', openingBalance: balance, currentBalance: balance, createdAt: _now);

void main() {
  final transactions = [
    _tx('t1', 'Swiggy', 680, 'expense', DateTime(2026, 8, 10), category: 'Food'),
    _tx('t2', 'Amazon', 2499, 'expense', DateTime(2026, 8, 15), category: 'Shopping'),
    _tx('t3', 'Salary', 72000, 'income', DateTime(2026, 8, 1), category: 'Income'),
    _tx('t4', 'Rent', 18000, 'expense', DateTime(2026, 8, 3), category: 'Housing'),
    _tx('t5', 'Big Purchase', 15000, 'expense', DateTime(2026, 8, 20)),
    _tx('t6', 'Groceries', 1200, 'expense', DateTime(2026, 7, 20), category: 'Food'),
  ];
  final wallets = [_wallet('w1', 'HDFC Savings', 50000, bankName: 'HDFC'), _wallet('w2', 'ICICI Savings', 5000, bankName: 'ICICI')];

  group('FinancialSearchEngine.search — keyword queries', () {
    test('"Swiggy" finds the matching transaction', () {
      final results = FinancialSearchEngine.search(
        query: 'Swiggy', transactions: transactions, wallets: wallets, recurringTransactions: const [], loans: const [], goals: const [], now: _now,
      );
      expect(results.any((r) => r.title == 'Swiggy'), isTrue);
    });

    test('"Amazon" finds the matching transaction', () {
      final results = FinancialSearchEngine.search(
        query: 'Amazon', transactions: transactions, wallets: wallets, recurringTransactions: const [], loans: const [], goals: const [], now: _now,
      );
      expect(results.any((r) => r.title == 'Amazon'), isTrue);
    });

    test('"salary" finds the income transaction', () {
      final results = FinancialSearchEngine.search(
        query: 'salary', transactions: transactions, wallets: wallets, recurringTransactions: const [], loans: const [], goals: const [], now: _now,
      );
      expect(results.any((r) => r.title == 'Salary'), isTrue);
    });

    test('"transactions above 5000" filters by amount', () {
      final results = FinancialSearchEngine.search(
        query: 'transactions above 5000', transactions: transactions, wallets: wallets, recurringTransactions: const [], loans: const [], goals: const [], now: _now,
      );
      expect(results.every((r) => r.amount! > 5000), isTrue);
      expect(results.any((r) => r.title == 'Salary'), isTrue);
      expect(results.any((r) => r.title == 'Swiggy'), isFalse);
    });

    test('"my biggest expenses" ranks expenses descending', () {
      final results = FinancialSearchEngine.search(
        query: 'my biggest expenses', transactions: transactions, wallets: wallets, recurringTransactions: const [], loans: const [], goals: const [], now: _now,
      );
      expect(results.first.title, 'Rent');
      expect(results.any((r) => r.title == 'Salary'), isFalse); // income excluded
    });

    test('"show income this month" returns only income in the current month', () {
      final results = FinancialSearchEngine.search(
        query: 'show income this month', transactions: transactions, wallets: wallets, recurringTransactions: const [], loans: const [], goals: const [], now: _now,
      );
      expect(results.length, 1);
      expect(results.single.title, 'Salary');
    });

    test('"show expenses last month" returns only last month\'s expenses', () {
      final results = FinancialSearchEngine.search(
        query: 'show expenses last month', transactions: transactions, wallets: wallets, recurringTransactions: const [], loans: const [], goals: const [], now: _now,
      );
      expect(results.length, 1);
      expect(results.single.title, 'Groceries');
    });

    test('"show transactions from HDFC" filters by wallet bank name', () {
      final results = FinancialSearchEngine.search(
        query: 'show transactions from hdfc', transactions: transactions, wallets: wallets, recurringTransactions: const [], loans: const [], goals: const [], now: _now,
      );
      expect(results, isNotEmpty);
      expect(results.every((r) => r.subtitle.contains('HDFC Savings')), isTrue);
    });

    test('"transactions between June 1 and June 30" filters by date range', () {
      final juneTx = [..._transactionsInJune()];
      final results = FinancialSearchEngine.search(
        query: 'transactions between June 1 and June 30', transactions: juneTx, wallets: wallets, recurringTransactions: const [], loans: const [], goals: const [], now: _now,
      );
      expect(results.length, 1);
      expect(results.single.title, 'June Purchase');
    });

    test('"what are my recurring payments" lists active recurring transactions', () {
      final recurring = [
        RecurringTransaction(id: 'r1', title: 'Netflix', amount: 649, categoryId: 'Subscriptions', accountId: 'w1', transactionType: 'expense', frequency: 'Monthly', startDate: DateTime(2026,1,1), nextDueDate: DateTime(2026,9,1), isActive: true, reminderDaysBefore: 1, note: '', createdAt: DateTime(2026,1,1), updatedAt: DateTime(2026,1,1)),
      ];
      final results = FinancialSearchEngine.search(
        query: 'what are my recurring payments', transactions: transactions, wallets: wallets, recurringTransactions: recurring, loans: const [], goals: const [], now: _now,
      );
      expect(results.any((r) => r.title == 'Netflix'), isTrue);
    });

    test('empty query returns no results', () {
      final results = FinancialSearchEngine.search(
        query: '', transactions: transactions, wallets: wallets, recurringTransactions: const [], loans: const [], goals: const [], now: _now,
      );
      expect(results, isEmpty);
    });

    test('a query matching nothing returns an empty list, never throws', () {
      final results = FinancialSearchEngine.search(
        query: 'zzzznonexistentmerchant', transactions: transactions, wallets: wallets, recurringTransactions: const [], loans: const [], goals: const [], now: _now,
      );
      expect(results, isEmpty);
    });

    test('transaction results carry a route and entityId so they can be opened', () {
      final results = FinancialSearchEngine.search(
        query: 'Swiggy', transactions: transactions, wallets: wallets, recurringTransactions: const [], loans: const [], goals: const [], now: _now,
      );
      final swiggy = results.firstWhere((r) => r.title == 'Swiggy');
      expect(swiggy.route, AppRoutes.transactions);
      expect(swiggy.entityId, 't1');
    });

    test('"show my Swiggy spending" extracts the merchant term, not just a bare "Swiggy" query', () {
      final results = FinancialSearchEngine.search(
        query: 'show my Swiggy spending', transactions: transactions, wallets: wallets, recurringTransactions: const [], loans: const [], goals: const [], now: _now,
      );
      expect(results.any((r) => r.title == 'Swiggy'), isTrue);
    });

    test('"show my loans" lists every loan, soonest due first', () {
      final loans = [
        Loan(id: 'l1', loanName: 'Car Loan', lenderName: 'Bank', loanType: 'Personal', principalAmount: 100000, interestRate: 10, tenureMonths: 24, emiAmount: 14500, outstandingAmount: 40000, paidAmount: 60000, accountId: 'w1', nextDueDate: DateTime(2026, 9, 10), startDate: DateTime(2025,1,1), endDate: DateTime(2027,1,1), totalInterest: 10000, status: 'Active', createdAt: DateTime(2025,1,1), updatedAt: DateTime(2025,1,1)),
        Loan(id: 'l2', loanName: 'Home Loan', lenderName: 'Bank', loanType: 'Home', principalAmount: 500000, interestRate: 8, tenureMonths: 240, emiAmount: 25000, outstandingAmount: 400000, paidAmount: 100000, accountId: 'w1', nextDueDate: DateTime(2026, 9, 1), startDate: DateTime(2025,1,1), endDate: DateTime(2045,1,1), totalInterest: 300000, status: 'Active', createdAt: DateTime(2025,1,1), updatedAt: DateTime(2025,1,1)),
      ];
      final results = FinancialSearchEngine.search(
        query: 'show my loans', transactions: transactions, wallets: wallets, recurringTransactions: const [], loans: loans, goals: const [], now: _now,
      );
      expect(results.length, 2);
      expect(results.first.title, 'Home Loan'); // due Sept 1, before Car Loan's Sept 10
    });

    test('"show my subscriptions" lists active recurring expense items', () {
      final recurring = [
        RecurringTransaction(id: 'r1', title: 'Netflix', amount: 649, categoryId: 'Subscriptions', accountId: 'w1', transactionType: 'expense', frequency: 'Monthly', startDate: DateTime(2026,1,1), nextDueDate: DateTime(2026,9,1), isActive: true, reminderDaysBefore: 1, note: '', createdAt: DateTime(2026,1,1), updatedAt: DateTime(2026,1,1)),
      ];
      final results = FinancialSearchEngine.search(
        query: 'show my subscriptions', transactions: transactions, wallets: wallets, recurringTransactions: recurring, loans: const [], goals: const [], now: _now,
      );
      expect(results.any((r) => r.title == 'Netflix'), isTrue);
    });

    test('"which subscriptions are costing me the most" ranks by real monthly-equivalent cost', () {
      final recurring = [
        RecurringTransaction(id: 'r1', title: 'Netflix', amount: 649, categoryId: 'Subscriptions', accountId: 'w1', transactionType: 'expense', frequency: 'Monthly', startDate: DateTime(2026,1,1), nextDueDate: DateTime(2026,9,1), isActive: true, reminderDaysBefore: 1, note: '', createdAt: DateTime(2026,1,1), updatedAt: DateTime(2026,1,1)),
        RecurringTransaction(id: 'r2', title: 'Domain', amount: 12000, categoryId: 'Subscriptions', accountId: 'w1', transactionType: 'expense', frequency: 'Yearly', startDate: DateTime(2026,1,1), nextDueDate: DateTime(2027,1,1), isActive: true, reminderDaysBefore: 1, note: '', createdAt: DateTime(2026,1,1), updatedAt: DateTime(2026,1,1)),
      ];
      final results = FinancialSearchEngine.search(
        query: 'which subscriptions are costing me the most', transactions: transactions, wallets: wallets, recurringTransactions: recurring, loans: const [], goals: const [], now: _now,
      );
      // Domain: 12000/12=1000/mo > Netflix: 649/mo
      expect(results.first.title, 'Domain');
    });

    test('wallet results carry a route to the wallet screen', () {
      final results = FinancialSearchEngine.search(
        query: 'HDFC', transactions: transactions, wallets: wallets, recurringTransactions: const [], loans: const [], goals: const [], now: _now,
      );
      final wallet = results.firstWhere((r) => r.type == FinancialSearchResultType.wallet);
      expect(wallet.route, AppRoutes.wallet);
      expect(wallet.entityId, 'w1');
    });
  });

  group('FinancialSearchEngine.answer — deterministic computed answers', () {
    test('"how much did I spend this month?" sums this month\'s expenses correctly', () {
      final result = FinancialSearchEngine.answer(query: 'how much did I spend this month', transactions: transactions, wallets: wallets, loans: const [], now: _now);
      expect(result, isNotNull);
      // Swiggy 680 + Amazon 2499 + Rent 18000 + Big Purchase 15000 = 36179
      expect(result!.amount, 680.0 + 2499.0 + 18000.0 + 15000.0);
    });

    test('"how much did I spend on food?" sums only the food category', () {
      final result = FinancialSearchEngine.answer(query: 'how much did I spend on food', transactions: transactions, wallets: wallets, loans: const [], now: _now);
      expect(result, isNotNull);
      expect(result!.amount, 680.0); // only Swiggy this month matches "food"
    });

    test('"which wallet has the most money?" identifies the richest wallet', () {
      final result = FinancialSearchEngine.answer(query: 'which wallet has the most money', transactions: transactions, wallets: wallets, loans: const [], now: _now);
      expect(result, isNotNull);
      expect(result!.answer, contains('HDFC Savings'));
      expect(result.amount, 50000.0);
    });

    test('"when is my next EMI?" finds the soonest active loan', () {
      final loans = [
        Loan(id: 'l1', loanName: 'Car Loan', lenderName: 'Bank', loanType: 'Personal', principalAmount: 100000, interestRate: 10, tenureMonths: 24, emiAmount: 14500, outstandingAmount: 50000, paidAmount: 50000, accountId: 'w1', nextDueDate: DateTime(2026, 9, 5), startDate: DateTime(2025,1,1), endDate: DateTime(2027,1,1), totalInterest: 10000, status: 'Active', createdAt: DateTime(2025,1,1), updatedAt: DateTime(2025,1,1)),
      ];
      final result = FinancialSearchEngine.answer(query: 'when is my next EMI', transactions: transactions, wallets: wallets, loans: loans, now: _now);
      expect(result, isNotNull);
      expect(result!.answer, contains('Car Loan'));
      expect(result.amount, 14500.0);
    });

    test('a non-question query returns null, deferring to search/AI', () {
      final result = FinancialSearchEngine.answer(query: 'Swiggy', transactions: transactions, wallets: wallets, loans: const [], now: _now);
      expect(result, isNull);
    });

    test('"how much money came in this month?" sums this month\'s income', () {
      final result = FinancialSearchEngine.answer(query: 'how much money came in this month', transactions: transactions, wallets: wallets, loans: const [], now: _now);
      expect(result, isNotNull);
      expect(result!.amount, 72000.0);
    });

    test('"how much money went out this month?" sums this month\'s expenses', () {
      final result = FinancialSearchEngine.answer(query: 'how much money went out this month', transactions: transactions, wallets: wallets, loans: const [], now: _now);
      expect(result, isNotNull);
      expect(result!.amount, 680.0 + 2499.0 + 18000.0 + 15000.0);
    });

    test('"what bills are due?" summarizes unpaid bills, soonest first', () {
      final bills = [
        Bill.create(id: 'b1', title: 'Electricity', amount: 1500, categoryId: 'Utilities', accountId: 'w1', dueDate: DateTime(2026, 9, 5), createdAt: _now),
        Bill.create(id: 'b2', title: 'Internet', amount: 999, categoryId: 'Utilities', accountId: 'w1', dueDate: DateTime(2026, 9, 1), createdAt: _now),
      ];
      final result = FinancialSearchEngine.answer(query: 'what bills are due', transactions: transactions, wallets: wallets, loans: const [], now: _now, bills: bills);
      expect(result, isNotNull);
      expect(result!.answer, contains('Internet'));
      expect(result.amount, 2499.0);
    });

    test('"what bills are due?" with nothing unpaid says so', () {
      final result = FinancialSearchEngine.answer(query: 'what bills are due', transactions: transactions, wallets: wallets, loans: const [], now: _now, bills: const []);
      expect(result, isNotNull);
      expect(result!.answer, contains('No bills'));
    });

    test('"how much did I spend this week?" sums this week\'s expenses', () {
      final result = FinancialSearchEngine.answer(query: 'how much did I spend this week', transactions: transactions, wallets: wallets, loans: const [], now: _now);
      expect(result, isNotNull);
      // Of the fixture transactions, only "Big Purchase" (Aug 20) falls within
      // the last 7 days of _now (2026-08-26 - 7 days = Aug 19).
      expect(result!.amount, 15000.0);
    });

    test('"where am I spending the most?" identifies the top category this month', () {
      final result = FinancialSearchEngine.answer(query: 'where am I spending the most', transactions: transactions, wallets: wallets, loans: const [], now: _now);
      expect(result, isNotNull);
      expect(result!.answer, contains('Housing')); // Rent 18000 is the single biggest category total
      expect(result.amount, 18000.0);
    });

    test('"how much do I owe?" sums outstanding balances across active loans', () {
      final loans = [
        Loan(id: 'l1', loanName: 'Car Loan', lenderName: 'Bank', loanType: 'Personal', principalAmount: 100000, interestRate: 10, tenureMonths: 24, emiAmount: 14500, outstandingAmount: 40000, paidAmount: 60000, accountId: 'w1', nextDueDate: DateTime(2026, 9, 5), startDate: DateTime(2025,1,1), endDate: DateTime(2027,1,1), totalInterest: 10000, status: 'Active', createdAt: DateTime(2025,1,1), updatedAt: DateTime(2025,1,1)),
      ];
      final result = FinancialSearchEngine.answer(query: 'how much do I owe', transactions: transactions, wallets: wallets, loans: loans, now: _now);
      expect(result, isNotNull);
      expect(result!.amount, 40000.0);
    });

    test('"how much can I safely spend?" is omitted without a SafeToSpendResult, present with one', () {
      final withoutResult = FinancialSearchEngine.answer(query: 'how much can I safely spend', transactions: transactions, wallets: wallets, loans: const [], now: _now);
      expect(withoutResult, isNull);

      const safeToSpend = SafeToSpendResult(
        availableMoney: 10000, upcomingCommitments: 2000, plannedSavings: 0, savingsIncluded: false,
        safeToSpend: 8000, dailySafeToSpend: 266, remainingDays: 30, hasSufficientData: true,
        shortfall: 0, commitmentBreakdown: [], windowDays: 30,
      );
      final result = FinancialSearchEngine.answer(query: 'how much can I safely spend', transactions: transactions, wallets: wallets, loans: const [], now: _now, safeToSpend: safeToSpend);
      expect(result, isNotNull);
      expect(result!.amount, 8000.0);
    });

    test('"how much recurring money do I have?" sums active recurring expenses at their monthly equivalent', () {
      final recurring = [
        RecurringTransaction(id: 'r1', title: 'Netflix', amount: 649, categoryId: 'Subscriptions', accountId: 'w1', transactionType: 'expense', frequency: 'Monthly', startDate: DateTime(2026,1,1), nextDueDate: DateTime(2026,9,1), isActive: true, reminderDaysBefore: 1, note: '', createdAt: DateTime(2026,1,1), updatedAt: DateTime(2026,1,1)),
        RecurringTransaction(id: 'r2', title: 'Domain renewal', amount: 1200, categoryId: 'Subscriptions', accountId: 'w1', transactionType: 'expense', frequency: 'Yearly', startDate: DateTime(2026,1,1), nextDueDate: DateTime(2027,1,1), isActive: true, reminderDaysBefore: 1, note: '', createdAt: DateTime(2026,1,1), updatedAt: DateTime(2026,1,1)),
      ];
      final result = FinancialSearchEngine.answer(query: 'how much recurring money do I have', transactions: transactions, wallets: wallets, loans: const [], now: _now, recurringTransactions: recurring);
      expect(result, isNotNull);
      expect(result!.amount, closeTo(649.0 + 100.0, 0.01));
    });
  });
}

List<Transaction> _transactionsInJune() {
  return [
    Transaction(id: 'j1', title: 'June Purchase', amount: 500, categoryId: 'General', accountId: 'w1', transactionType: 'expense', paymentMethod: 'card', note: '', createdAt: DateTime(2026, 6, 15)),
    Transaction(id: 'j2', title: 'July Purchase', amount: 500, categoryId: 'General', accountId: 'w1', transactionType: 'expense', paymentMethod: 'card', note: '', createdAt: DateTime(2026, 7, 15)),
  ];
}
