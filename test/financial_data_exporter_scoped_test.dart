import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:paysense/shared/models/bill.dart';
import 'package:paysense/shared/models/budget.dart';
import 'package:paysense/shared/models/goal.dart';
import 'package:paysense/shared/models/loan.dart';
import 'package:paysense/shared/models/recurring_transaction.dart';
import 'package:paysense/shared/models/transaction.dart';
import 'package:paysense/shared/models/wallet.dart';
import 'package:paysense/shared/repositories/transaction_repository.dart';
import 'package:paysense/shared/repositories/wallet_repository.dart';
import 'package:paysense/shared/utils/financial_data_exporter.dart';

/// A minimal fake so `getApplicationDocumentsDirectory()` doesn't need a
/// real platform channel in tests — no existing test in this repo has
/// previously exercised `FinancialDataExporter`'s actual file-writing
/// path (only its pure `buildExportData()`), so this fake is new.
class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.path);
  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

Future<void> _initHive(Directory dir) async {
  Hive.init(dir.path);
  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(WalletAdapter());
  }
  if (!Hive.isAdapterRegistered(2)) {
    Hive.registerAdapter(TransactionAdapter());
  }
  if (!Hive.isAdapterRegistered(3)) {
    Hive.registerAdapter(BudgetAdapter());
  }
  if (!Hive.isAdapterRegistered(4)) {
    Hive.registerAdapter(GoalAdapter());
  }
  if (!Hive.isAdapterRegistered(5)) {
    Hive.registerAdapter(RecurringTransactionAdapter());
  }
  if (!Hive.isAdapterRegistered(6)) {
    Hive.registerAdapter(BillAdapter());
  }
  if (!Hive.isAdapterRegistered(7)) {
    Hive.registerAdapter(LoanAdapter());
  }
  await Hive.openBox<Wallet>('wallets');
  await Hive.openBox<Transaction>('transactions');
  await Hive.openBox<Budget>('budgets');
  await Hive.openBox<Goal>('goals');
  await Hive.openBox<RecurringTransaction>('recurring_transactions');
  await Hive.openBox<Bill>('bills');
  await Hive.openBox<Loan>('loans');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('paysense_export_scoped_test');
    await _initHive(tempDir);
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('buildScopedExportData — scope selection', () {
    test('only requested scopes are included in the output', () async {
      await WalletRepository.instance.add(
        Wallet(id: 'w1', name: 'Cash', bankName: '', type: 'cash', openingBalance: 100, currentBalance: 100, createdAt: DateTime(2026, 1, 1)),
      );

      final data = await FinancialDataExporter.instance.buildScopedExportData({ExportScope.wallets});
      expect(data.containsKey('wallets'), isTrue);
      expect(data.containsKey('transactions'), isFalse);
      expect(data.containsKey('budgets'), isFalse);
    });

    test('an empty scope set exports nothing but the timestamp — never crashes', () async {
      final data = await FinancialDataExporter.instance.buildScopedExportData({});
      expect(data.keys, ['exportedAt']);
    });

    test('financialSummary scope contains only aggregate counts/sums, never raw records', () async {
      await WalletRepository.instance.add(
        Wallet(id: 'w1', name: 'Cash', bankName: '', type: 'cash', openingBalance: 500, currentBalance: 500, createdAt: DateTime(2026, 1, 1)),
      );
      final data = await FinancialDataExporter.instance.buildScopedExportData({ExportScope.financialSummary});
      final summary = data['financialSummary'] as Map<String, dynamic>;
      expect(summary['totalWalletBalance'], 500.0);
      expect(summary['walletCount'], 1);
      expect(data.containsKey('wallets'), isFalse); // no raw wallet records leaked
    });
  });

  group('exportScopedToJsonFile', () {
    test('produces valid, parseable JSON with correct record counts', () async {
      await WalletRepository.instance.add(
        Wallet(id: 'w1', name: 'Cash', bankName: '', type: 'cash', openingBalance: 100, currentBalance: 100, createdAt: DateTime(2026, 1, 1)),
      );
      await TransactionRepository.instance.add(
        Transaction(id: 't1', title: 'Coffee', amount: 150, categoryId: 'Food', accountId: 'w1', transactionType: 'expense', paymentMethod: 'card', note: '', createdAt: DateTime(2026, 8, 1)),
      );

      final path = await FinancialDataExporter.instance.exportScopedToJsonFile({ExportScope.wallets, ExportScope.transactions});
      final file = File(path);
      expect(await file.exists(), isTrue);

      final decoded = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      expect((decoded['wallets'] as List).length, 1);
      expect((decoded['transactions'] as List).length, 1);

      await file.delete();
    });

    test('handles empty data without crashing', () async {
      final path = await FinancialDataExporter.instance.exportScopedToJsonFile({ExportScope.transactions});
      final decoded = jsonDecode(await File(path).readAsString()) as Map<String, dynamic>;
      expect(decoded['transactions'], isEmpty);
      await File(path).delete();
    });

    test('Unicode and special-character merchant names round-trip correctly', () async {
      await WalletRepository.instance.add(
        Wallet(id: 'w1', name: 'Cash', bankName: '', type: 'cash', openingBalance: 0, currentBalance: 0, createdAt: DateTime(2026, 1, 1)),
      );
      await TransactionRepository.instance.add(
        Transaction(
          id: 't1',
          title: 'Café "Zürich" — 日本語 & 50% off, ₹100',
          amount: 100,
          categoryId: 'Food',
          accountId: 'w1',
          transactionType: 'expense',
          paymentMethod: 'card',
          note: '',
          createdAt: DateTime(2026, 8, 1),
        ),
      );
      final path = await FinancialDataExporter.instance.exportScopedToJsonFile({ExportScope.transactions});
      final decoded = jsonDecode(await File(path).readAsString()) as Map<String, dynamic>;
      final title = (decoded['transactions'] as List).first['title'] as String;
      expect(title, 'Café "Zürich" — 日本語 & 50% off, ₹100');
      await File(path).delete();
    });
  });

  group('exportScopedToCsvFile', () {
    test('produces a valid CSV with a header row and one row per record', () async {
      await WalletRepository.instance.add(
        Wallet(id: 'w1', name: 'HDFC', bankName: 'HDFC', type: 'bank', openingBalance: 1000, currentBalance: 1200, createdAt: DateTime(2026, 1, 1)),
      );
      await WalletRepository.instance.add(
        Wallet(id: 'w2', name: 'ICICI', bankName: 'ICICI', type: 'bank', openingBalance: 500, currentBalance: 500, createdAt: DateTime(2026, 1, 1)),
      );

      final path = await FinancialDataExporter.instance.exportScopedToCsvFile(ExportScope.wallets);
      final lines = await File(path).readAsLines();
      expect(lines.first, contains('name'));
      expect(lines.length, 3); // header + 2 wallets
      await File(path).delete();
    });

    test('a comma or quote inside a field is safely escaped, never corrupting the CSV structure', () async {
      await WalletRepository.instance.add(
        Wallet(id: 'w1', name: 'Cash', bankName: '', type: 'cash', openingBalance: 0, currentBalance: 0, createdAt: DateTime(2026, 1, 1)),
      );
      await TransactionRepository.instance.add(
        Transaction(id: 't1', title: 'Groceries, "big" shop', amount: 500, categoryId: 'Food', accountId: 'w1', transactionType: 'expense', paymentMethod: 'card', note: '', createdAt: DateTime(2026, 8, 1)),
      );
      final path = await FinancialDataExporter.instance.exportScopedToCsvFile(ExportScope.transactions);
      final lines = await File(path).readAsLines();
      expect(lines.length, 2); // still exactly one header + one data row
      await File(path).delete();
    });

    test('empty data still produces a valid CSV with only a header row', () async {
      final path = await FinancialDataExporter.instance.exportScopedToCsvFile(ExportScope.loans);
      final lines = await File(path).readAsLines();
      expect(lines.length, 1);
      await File(path).delete();
    });
  });

  group('Privacy — export never contains forbidden fields', () {
    test('a scoped JSON export contains no password/secret/token/credential fields', () async {
      await WalletRepository.instance.add(
        Wallet(id: 'w1', name: 'Cash', bankName: '', type: 'cash', openingBalance: 100, currentBalance: 100, createdAt: DateTime(2026, 1, 1)),
      );
      final path = await FinancialDataExporter.instance.exportScopedToJsonFile({ExportScope.wallets, ExportScope.financialSummary});
      final serialized = (await File(path).readAsString()).toLowerCase();
      for (final fragment in ['password', 'passwd', 'pin', 'otp', 'cvv', 'cardnumber', 'secret', 'token', 'credential']) {
        expect(serialized.contains(fragment), isFalse, reason: 'forbidden fragment "$fragment" leaked into export');
      }
      await File(path).delete();
    });
  });
}
