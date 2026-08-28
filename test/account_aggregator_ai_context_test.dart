import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:paysense/features/ai/services/financial_context_builder.dart';
import 'package:paysense/shared/models/account.dart';
import 'package:paysense/shared/models/bill.dart';
import 'package:paysense/shared/models/budget.dart';
import 'package:paysense/shared/models/goal.dart';
import 'package:paysense/shared/models/loan.dart';
import 'package:paysense/shared/models/notification_record.dart';
import 'package:paysense/shared/models/recurring_transaction.dart';
import 'package:paysense/shared/models/sms_review_item.dart';
import 'package:paysense/shared/models/transaction.dart';
import 'package:paysense/shared/models/user_profile.dart';
import 'package:paysense/shared/models/wallet.dart';
import 'package:paysense/shared/repositories/account_aggregator_connection_repository.dart';
import 'package:paysense/shared/services/account_aggregator/account_aggregator_models.dart';

// Mirrors test/financial_context_builder_test.dart's own `_initHive`
// exactly — `FinancialContextBuilder.build()` reads from every one of
// these repositories, not just the AA one this file is actually testing.
Future<void> _initHive(Directory dir) async {
  Hive.init(dir.path);
  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(UserProfileAdapter());
  }
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
  if (!Hive.isAdapterRegistered(8)) {
    Hive.registerAdapter(AccountAdapter());
  }
  if (!Hive.isAdapterRegistered(9)) {
    Hive.registerAdapter(AppNotificationAdapter());
  }
  if (!Hive.isAdapterRegistered(10)) {
    Hive.registerAdapter(SmsReviewItemAdapter());
  }

  await Hive.openBox<UserProfile>('user_profile');
  await Hive.openBox<Wallet>('wallets');
  await Hive.openBox<Transaction>('transactions');
  await Hive.openBox<Budget>('budgets');
  await Hive.openBox<Goal>('goals');
  await Hive.openBox<RecurringTransaction>('recurring_transactions');
  await Hive.openBox('app_settings');
  await Hive.openBox<Bill>('bills');
  await Hive.openBox<Loan>('loans');
  await Hive.openBox<Account>('accounts');
  await Hive.openBox('auth_session');
  await Hive.openBox<AppNotification>('app_notifications');
  await Hive.openBox<SmsReviewItem>('sms_review_items');
  await Hive.openBox('sms_processed_fingerprints');
}

final _referenceDate = DateTime(2026, 8, 26);

AccountAggregatorConnection _connection({
  ConnectionStatus status = ConnectionStatus.connected,
  DateTime? lastSyncedAt,
}) {
  return AccountAggregatorConnection(
    connectionId: 'conn-1',
    providerId: 'mock',
    providerName: 'Sandbox / Mock Provider',
    status: status,
    consentStatus: ConsentStatus.approved,
    createdAt: _referenceDate,
    updatedAt: _referenceDate,
    lastSyncedAt: lastSyncedAt,
    accounts: const [
      AccountAggregatorAccount(
        id: 'acc-1',
        displayName: 'HDFC Savings',
        institutionName: 'HDFC Bank',
        institutionType: FinancialInstitutionType.bank,
        maskedIdentifier: '•••• 1234',
        linkedWalletId: 'wallet-1',
      ),
    ],
  );
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('paysense_aa_ai_context_test');
    await _initHive(tempDir);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('no connection: accountAggregatorContext reports isConnected=false', () async {
    final context = await FinancialContextBuilder.instance.build();
    expect(context.accountAggregatorContext['isConnected'], isFalse);
    expect(context.accountAggregatorContext['connectedAccountCount'], 0);
  });

  test('an active connection is reflected accurately: count, last sync, account names', () async {
    await AccountAggregatorConnectionRepository.instance.upsert(_connection(lastSyncedAt: _referenceDate));

    final context = await FinancialContextBuilder.instance.build();
    final aa = context.accountAggregatorContext;

    expect(aa['isConnected'], isTrue);
    expect(aa['connectionCount'], 1);
    expect(aa['connectedAccountCount'], 1);
    expect(aa['accountDisplayNames'], contains('HDFC Savings'));
    expect(aa['lastSyncedAt'], _referenceDate.toIso8601String());
    expect(aa['anySyncFailed'], isFalse);
    expect(aa['isMockData'], isTrue);
  });

  test('a failed connection is surfaced so the AI can answer "did my bank sync succeed"', () async {
    await AccountAggregatorConnectionRepository.instance.upsert(_connection(status: ConnectionStatus.failed));

    final context = await FinancialContextBuilder.instance.build();
    expect(context.accountAggregatorContext['anySyncFailed'], isTrue);
  });

  test('a revoked connection is excluded from the active count', () async {
    await AccountAggregatorConnectionRepository.instance.upsert(_connection(status: ConnectionStatus.revoked));

    final context = await FinancialContextBuilder.instance.build();
    expect(context.accountAggregatorContext['isConnected'], isFalse);
  });

  test('privacy: the AA context never contains a forbidden fragment or raw account identifier', () async {
    await AccountAggregatorConnectionRepository.instance.upsert(_connection(lastSyncedAt: _referenceDate));

    final context = await FinancialContextBuilder.instance.build();
    final serialized = jsonEncode(context.toMap()).toLowerCase();

    for (final fragment in ['password', 'pin', 'otp', 'cvv', 'cardnumber', 'accountnumber', 'secret', 'token', 'credential']) {
      expect(serialized.contains(fragment), isFalse, reason: 'forbidden fragment "$fragment" leaked into AI context');
    }
    // The masked identifier itself must never appear — only the safe
    // display name/count/timestamp fields do.
    expect(serialized.contains('1234'), isFalse);
  });
}
