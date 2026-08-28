import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';

import '../repositories/bill_repository.dart';
import '../repositories/budget_repository.dart';
import '../repositories/goal_repository.dart';
import '../repositories/loan_repository.dart';
import '../repositories/recurring_transaction_repository.dart';
import '../repositories/transaction_repository.dart';
import '../repositories/wallet_repository.dart';

/// DATA EXPORT / BACKUP — which data section(s) the user chose to
/// export. [financialSummary] is a small set of aggregate totals
/// (counts/sums only — no financial formula, nothing a calculator
/// computes) rather than raw records.
enum ExportScope { transactions, wallets, budgets, goals, recurringTransactions, bills, loans, financialSummary }

enum ExportFormat { json, csv }

/// Builds a JSON export of the user's locally stored financial data and
/// writes it to the app's own documents directory. Export stays entirely
/// on-device — nothing is uploaded or shared off the app sandbox.
class FinancialDataExporter {
  FinancialDataExporter._();

  static final FinancialDataExporter instance = FinancialDataExporter._();

  Future<Map<String, dynamic>> buildExportData() async {
    final wallets = await WalletRepository.instance.getAll();
    final transactions = await TransactionRepository.instance.getAll();
    final budgets = await BudgetRepository.instance.getAll();
    final goals = await GoalRepository.instance.getAll();
    final recurring = await RecurringTransactionRepository.instance.getAll();
    final bills = await BillRepository.instance.getAll();
    final loans = await LoanRepository.instance.getAll();

    return <String, dynamic>{
      'exportedAt': DateTime.now().toIso8601String(),
      'wallets': wallets.map((w) => w.toMap()).toList(),
      'transactions': transactions.map((t) => t.toMap()).toList(),
      'budgets': budgets.map((b) => b.toMap()).toList(),
      'goals': goals.map((g) => g.toMap()).toList(),
      'recurringTransactions': recurring.map((r) => r.toMap()).toList(),
      'bills': bills.map((b) => b.toMap()).toList(),
      'loans': loans.map((l) => l.toMap()).toList(),
    };
  }

  /// Writes the export as pretty-printed JSON to the app documents
  /// directory and returns the file path.
  Future<String> exportToFile() async {
    final data = await buildExportData();
    final json = const JsonEncoder.withIndent('  ').convert(data);

    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${directory.path}/paysense_export_$timestamp.json');
    await file.writeAsString(json);
    return file.path;
  }

  // ---------------------------------------------------------------------
  // DATA EXPORT / BACKUP — scoped export (JSON or CSV), on top of the
  // existing buildExportData()/exportToFile() above, which stay exactly
  // as-is for the pre-existing Settings "Export financial data" entry.
  // ---------------------------------------------------------------------

  /// Builds ONLY the requested [scopes] — never more than the user asked
  /// for (PART J's explicit "allow the user to choose export scope").
  Future<Map<String, dynamic>> buildScopedExportData(Set<ExportScope> scopes) async {
    final data = <String, dynamic>{'exportedAt': DateTime.now().toIso8601String()};

    if (scopes.contains(ExportScope.wallets)) {
      data['wallets'] = (await WalletRepository.instance.getAll()).map((w) => w.toMap()).toList();
    }
    if (scopes.contains(ExportScope.transactions)) {
      data['transactions'] = (await TransactionRepository.instance.getAll()).map((t) => t.toMap()).toList();
    }
    if (scopes.contains(ExportScope.budgets)) {
      data['budgets'] = (await BudgetRepository.instance.getAll()).map((b) => b.toMap()).toList();
    }
    if (scopes.contains(ExportScope.goals)) {
      data['goals'] = (await GoalRepository.instance.getAll()).map((g) => g.toMap()).toList();
    }
    if (scopes.contains(ExportScope.recurringTransactions)) {
      data['recurringTransactions'] = (await RecurringTransactionRepository.instance.getAll()).map((r) => r.toMap()).toList();
    }
    if (scopes.contains(ExportScope.bills)) {
      data['bills'] = (await BillRepository.instance.getAll()).map((b) => b.toMap()).toList();
    }
    if (scopes.contains(ExportScope.loans)) {
      data['loans'] = (await LoanRepository.instance.getAll()).map((l) => l.toMap()).toList();
    }
    if (scopes.contains(ExportScope.financialSummary)) {
      data['financialSummary'] = await _buildFinancialSummary();
    }

    return data;
  }

  /// Simple counts/sums only — never a duplicated financial formula
  /// (savings rate, health score, etc. stay owned by their existing
  /// calculators and are never recomputed here).
  Future<Map<String, dynamic>> _buildFinancialSummary() async {
    final wallets = await WalletRepository.instance.getAll();
    final transactions = await TransactionRepository.instance.getAll();
    final budgets = await BudgetRepository.instance.getAll();
    final goals = await GoalRepository.instance.getAll();
    final loans = await LoanRepository.instance.getAll();

    return {
      'totalWalletBalance': wallets.fold<double>(0, (sum, w) => sum + w.currentBalance),
      'walletCount': wallets.length,
      'transactionCount': transactions.length,
      'totalBudgetAllocated': budgets.fold<double>(0, (sum, b) => sum + b.allocatedAmount),
      'totalBudgetSpent': budgets.fold<double>(0, (sum, b) => sum + b.spentAmount),
      'totalGoalTarget': goals.fold<double>(0, (sum, g) => sum + g.targetAmount),
      'totalGoalSaved': goals.fold<double>(0, (sum, g) => sum + g.currentAmount),
      'totalLoanOutstanding': loans.fold<double>(0, (sum, l) => sum + l.outstandingAmount),
      'activeLoanCount': loans.where((l) => l.isActive).length,
    };
  }

  Future<String> exportScopedToJsonFile(Set<ExportScope> scopes) async {
    final data = await buildScopedExportData(scopes);
    final json = const JsonEncoder.withIndent('  ').convert(data);
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${directory.path}/paysense_export_$timestamp.json');
    await file.writeAsString(json);
    return file.path;
  }

  /// CSV export supports exactly ONE scope at a time — a CSV file is a
  /// single table, and PaySense's data sections have different schemas
  /// (a transaction and a goal share no columns), so combining several
  /// into one CSV would either be misleading or require inventing a
  /// merged schema. The UI only offers CSV once a single scope is
  /// selected (see [DataExportScreen]); [financialSummary] also supports
  /// CSV, as a single key/value table.
  Future<String> exportScopedToCsvFile(ExportScope scope) async {
    final rows = await _csvRowsFor(scope);
    final csv = const ListToCsvConverter().convert(rows);
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${directory.path}/paysense_export_${scope.name}_$timestamp.csv');
    await file.writeAsString(csv);
    return file.path;
  }

  Future<List<List<dynamic>>> _csvRowsFor(ExportScope scope) async {
    switch (scope) {
      case ExportScope.wallets:
        final wallets = await WalletRepository.instance.getAll();
        return [
          ['id', 'name', 'bankName', 'type', 'openingBalance', 'currentBalance', 'createdAt'],
          for (final w in wallets) [w.id, w.name, w.bankName, w.type, w.openingBalance, w.currentBalance, w.createdAt.toIso8601String()],
        ];
      case ExportScope.transactions:
        final transactions = await TransactionRepository.instance.getAll();
        return [
          ['id', 'title', 'amount', 'categoryId', 'accountId', 'transactionType', 'paymentMethod', 'note', 'createdAt'],
          for (final t in transactions)
            [t.id, t.title, t.amount, t.categoryId, t.accountId, t.transactionType, t.paymentMethod, t.note, t.createdAt.toIso8601String()],
        ];
      case ExportScope.budgets:
        final budgets = await BudgetRepository.instance.getAll();
        return [
          ['id', 'categoryName', 'allocatedAmount', 'spentAmount', 'remainingAmount', 'month', 'year'],
          for (final b in budgets) [b.id, b.categoryName, b.allocatedAmount, b.spentAmount, b.remainingAmount, b.month, b.year],
        ];
      case ExportScope.goals:
        final goals = await GoalRepository.instance.getAll();
        return [
          ['id', 'title', 'targetAmount', 'currentAmount', 'targetDate', 'category', 'isCompleted'],
          for (final g in goals) [g.id, g.title, g.targetAmount, g.currentAmount, g.targetDate.toIso8601String(), g.category, g.isCompleted],
        ];
      case ExportScope.recurringTransactions:
        final recurring = await RecurringTransactionRepository.instance.getAll();
        return [
          ['id', 'title', 'amount', 'frequency', 'nextDueDate', 'isActive'],
          for (final r in recurring) [r.id, r.title, r.amount, r.frequency, r.nextDueDate.toIso8601String(), r.isActive],
        ];
      case ExportScope.bills:
        final bills = await BillRepository.instance.getAll();
        return [
          ['id', 'title', 'amount', 'dueDate', 'isPaid', 'isRecurring', 'frequency'],
          for (final b in bills) [b.id, b.title, b.amount, b.dueDate.toIso8601String(), b.isPaid, b.isRecurring, b.frequency],
        ];
      case ExportScope.loans:
        final loans = await LoanRepository.instance.getAll();
        return [
          ['id', 'loanName', 'lenderName', 'principalAmount', 'emiAmount', 'outstandingAmount', 'status'],
          for (final l in loans) [l.id, l.loanName, l.lenderName, l.principalAmount, l.emiAmount, l.outstandingAmount, l.status],
        ];
      case ExportScope.financialSummary:
        final summary = await _buildFinancialSummary();
        return [
          ['metric', 'value'],
          for (final entry in summary.entries) [entry.key, entry.value],
        ];
    }
  }
}
