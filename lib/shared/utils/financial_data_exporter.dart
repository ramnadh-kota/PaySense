import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../repositories/bill_repository.dart';
import '../repositories/budget_repository.dart';
import '../repositories/goal_repository.dart';
import '../repositories/loan_repository.dart';
import '../repositories/recurring_transaction_repository.dart';
import '../repositories/transaction_repository.dart';
import '../repositories/wallet_repository.dart';

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
}
