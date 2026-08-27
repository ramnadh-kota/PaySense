import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:paysense/shared/models/account.dart';
import 'package:paysense/shared/models/app_settings.dart';
import 'package:paysense/shared/models/bill.dart';
import 'package:paysense/shared/models/budget.dart';
import 'package:paysense/shared/models/goal.dart';
import 'package:paysense/shared/models/loan.dart';
import 'package:paysense/shared/models/recurring_transaction.dart';
import 'package:paysense/shared/models/transaction.dart';
import 'package:paysense/shared/models/user_profile.dart';
import 'package:paysense/shared/models/wallet.dart';
import 'package:paysense/shared/providers/auth_provider.dart';
import 'package:paysense/shared/providers/settings_provider.dart';
import 'package:paysense/shared/providers/user_profile_provider.dart';
import 'package:paysense/shared/repositories/account_repository.dart';
import 'package:paysense/shared/repositories/bill_repository.dart';
import 'package:paysense/shared/repositories/budget_repository.dart';
import 'package:paysense/shared/repositories/goal_repository.dart';
import 'package:paysense/shared/repositories/loan_repository.dart';
import 'package:paysense/shared/repositories/recurring_transaction_repository.dart';
import 'package:paysense/shared/repositories/transaction_repository.dart';
import 'package:paysense/shared/repositories/wallet_repository.dart';
import 'package:paysense/shared/services/account_scope.dart';
import 'package:paysense/shared/utils/currency_formatter.dart';
import 'package:paysense/shared/utils/financial_data_exporter.dart';
import 'package:paysense/shared/utils/password_hasher.dart';

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

  await Hive.openBox<UserProfile>('user_profile');
  await Hive.openBox<Wallet>('wallets');
  await Hive.openBox<Transaction>('transactions');
  await Hive.openBox<Budget>('budgets');
  await Hive.openBox<Goal>('goals');
  await Hive.openBox<RecurringTransaction>('recurring_transactions');
  await Hive.openBox<Bill>('bills');
  await Hive.openBox<Loan>('loans');
  await Hive.openBox<Account>('accounts');
  await Hive.openBox('auth_session');
  await Hive.openBox('app_settings');
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('paysense_settings_test');
    await _initHive(tempDir);
  });

  tearDown(() async {
    AccountScope.instance.deactivate();
    await Hive.deleteFromDisk();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('settings default to system theme and all reminders enabled', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final settings = await container.read(settingsProvider.future);
    expect(settings.themeMode, AppThemeMode.system);
    expect(settings.billReminders, isTrue);
    expect(settings.recurringReminders, isTrue);
    expect(settings.loanReminders, isTrue);
  });

  test('theme preference persists across a fresh provider container', () async {
    final firstContainer = ProviderContainer();
    await firstContainer.read(settingsProvider.notifier).setThemeMode(
      AppThemeMode.dark,
    );
    firstContainer.dispose();

    final secondContainer = ProviderContainer();
    addTearDown(secondContainer.dispose);

    final settings = await secondContainer.read(settingsProvider.future);
    expect(settings.themeMode, AppThemeMode.dark);
  });

  test('notification preferences toggle independently and persist', () async {
    final firstContainer = ProviderContainer();
    await firstContainer.read(settingsProvider.notifier).setBillReminders(false);
    await firstContainer
        .read(settingsProvider.notifier)
        .setRecurringReminders(false);
    firstContainer.dispose();

    final secondContainer = ProviderContainer();
    addTearDown(secondContainer.dispose);

    final settings = await secondContainer.read(settingsProvider.future);
    expect(settings.billReminders, isFalse);
    expect(settings.recurringReminders, isFalse);
    expect(settings.loanReminders, isTrue);
  });

  test('currency preference lives on UserProfile and maps to the right symbol', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final now = DateTime.now();
    await container.read(userProfileProvider.notifier).saveProfile(
      UserProfile(
        id: 'profile',
        fullName: 'Jane Doe',
        currency: 'USD',
        createdAt: now,
        updatedAt: now,
      ),
    );

    final profile = await container.read(userProfileProvider.future);
    expect(profile!.currency, 'USD');
    expect(CurrencyFormatter.symbolFor(profile.currency), '\$');
  });

  test('changePassword updates the hash and rejects the wrong current password', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(authProvider.notifier).signUp(
      fullName: 'Jane Doe',
      email: 'jane@example.com',
      password: 'oldpassword1',
    );

    await expectLater(
      container.read(authProvider.notifier).changePassword(
        currentPassword: 'wrong-password',
        newPassword: 'newpassword1',
      ),
      throwsA(isA<AuthException>()),
    );

    await container.read(authProvider.notifier).changePassword(
      currentPassword: 'oldpassword1',
      newPassword: 'newpassword1',
    );

    final account = await AccountRepository.instance.getByEmail(
      'jane@example.com',
    );
    expect(
      PasswordHasher.verify('newpassword1', account!.passwordSalt, account.passwordHash),
      isTrue,
    );
    expect(
      PasswordHasher.verify('oldpassword1', account.passwordSalt, account.passwordHash),
      isFalse,
    );
  });

  test('exported data includes all financial records with correct counts', () async {
    final now = DateTime.now();
    await WalletRepository.instance.add(
      Wallet(
        id: 'w1',
        name: 'Cash',
        bankName: '',
        type: 'cash',
        openingBalance: 100,
        currentBalance: 100,
        createdAt: now,
      ),
    );
    await BillRepository.instance.add(
      Bill.create(
        id: 'b1',
        title: 'Internet',
        amount: 500,
        categoryId: 'Utilities',
        accountId: 'Cash',
        dueDate: now,
        createdAt: now,
      ),
    );

    final export = await FinancialDataExporter.instance.buildExportData();
    expect(export['wallets'], hasLength(1));
    expect(export['bills'], hasLength(1));
    expect(export['transactions'], isEmpty);
    expect(export.containsKey('exportedAt'), isTrue);
  });

  test('clearFinancialData wipes financial boxes but preserves account, '
      'profile, and settings', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(authProvider.notifier).signUp(
      fullName: 'Jane Doe',
      email: 'jane@example.com',
      password: 'password123',
    );
    await container.read(settingsProvider.notifier).setThemeMode(
      AppThemeMode.dark,
    );

    final now = DateTime.now();
    await WalletRepository.instance.add(
      Wallet(
        id: 'w1',
        name: 'Cash',
        bankName: '',
        type: 'cash',
        openingBalance: 100,
        currentBalance: 100,
        createdAt: now,
      ),
    );
    await TransactionRepository.instance.add(
      Transaction(
        id: 't1',
        title: 'Groceries',
        amount: 50,
        categoryId: 'Food',
        accountId: 'Cash',
        transactionType: 'expense',
        paymentMethod: '',
        note: '',
        createdAt: now,
      ),
    );
    await BudgetRepository.instance.add(
      Budget.create(
        id: 'bg1',
        categoryId: 'Food',
        categoryName: 'Food',
        allocatedAmount: 1000,
        month: 'August',
        year: 2026,
        createdAt: now,
      ),
    );
    await GoalRepository.instance.add(
      Goal.create(
        id: 'g1',
        title: 'Emergency Fund',
        targetAmount: 10000,
        targetDate: now.add(const Duration(days: 365)),
        category: 'Savings',
        icon: 'savings',
        color: 0xFF000000,
        createdAt: now,
      ),
    );
    await BillRepository.instance.add(
      Bill.create(
        id: 'b1',
        title: 'Internet',
        amount: 500,
        categoryId: 'Utilities',
        accountId: 'Cash',
        dueDate: now,
        createdAt: now,
      ),
    );

    await container.read(settingsProvider.notifier).clearFinancialData();

    expect(await WalletRepository.instance.getAll(), isEmpty);
    expect(await TransactionRepository.instance.getAll(), isEmpty);
    expect(await BudgetRepository.instance.getAll(), isEmpty);
    expect(await GoalRepository.instance.getAll(), isEmpty);
    expect(await BillRepository.instance.getAll(), isEmpty);
    expect(await RecurringTransactionRepository.instance.getAll(), isEmpty);
    expect(await LoanRepository.instance.getAll(), isEmpty);

    // Account, profile, and settings must survive.
    expect(await AccountRepository.instance.exists('jane@example.com'), isTrue);
    final profile = await container.read(userProfileProvider.future);
    expect(profile, isNotNull);
    expect(profile!.fullName, 'Jane Doe');
    final settings = await container.read(settingsProvider.future);
    expect(settings.themeMode, AppThemeMode.dark);
  });
}
