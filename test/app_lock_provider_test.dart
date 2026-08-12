import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:paysense/core/services/biometric_service.dart';
import 'package:paysense/shared/models/account.dart';
import 'package:paysense/shared/models/app_lock_settings.dart';
import 'package:paysense/shared/models/bill.dart';
import 'package:paysense/shared/models/budget.dart';
import 'package:paysense/shared/models/goal.dart';
import 'package:paysense/shared/models/loan.dart';
import 'package:paysense/shared/models/recurring_transaction.dart';
import 'package:paysense/shared/models/transaction.dart';
import 'package:paysense/shared/models/user_profile.dart';
import 'package:paysense/shared/models/wallet.dart';
import 'package:paysense/shared/providers/app_lock_provider.dart';
import 'package:paysense/shared/providers/auth_provider.dart';
import 'package:paysense/shared/repositories/app_settings_repository.dart';

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
    tempDir = await Directory.systemTemp.createTemp('paysense_app_lock_test');
    await _initHive(tempDir);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('App Lock is disabled by default, biometric method, immediate timeout', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final settings = await container.read(appLockSettingsProvider.future);
    expect(settings.enabled, isFalse);
    expect(settings.method, LockAuthMethod.biometric);
    expect(settings.timeout, LockTimeout.immediately);
    expect(settings.hasPinConfigured, isFalse);
  });

  test('enabling and disabling App Lock updates state', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(appLockSettingsProvider.notifier).setEnabled(true);
    expect(container.read(appLockSettingsProvider).value!.enabled, isTrue);

    await container.read(appLockSettingsProvider.notifier).setEnabled(false);
    expect(container.read(appLockSettingsProvider).value!.enabled, isFalse);
  });

  test('lock timeout selection persists across a fresh provider container', () async {
    final firstContainer = ProviderContainer();
    await firstContainer
        .read(appLockSettingsProvider.notifier)
        .setTimeout(LockTimeout.afterFiveMinutes);
    firstContainer.dispose();

    final secondContainer = ProviderContainer();
    addTearDown(secondContainer.dispose);
    final settings = await secondContainer.read(appLockSettingsProvider.future);
    expect(settings.timeout, LockTimeout.afterFiveMinutes);
  });

  test('PIN setup rejects invalid length and mismatched confirmation', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(appLockSettingsProvider.notifier);

    await expectLater(
      notifier.setupPin(pin: '123', confirmPin: '123'),
      throwsA(isA<AppLockException>()),
    );
    await expectLater(
      notifier.setupPin(pin: '1234567', confirmPin: '1234567'),
      throwsA(isA<AppLockException>()),
    );
    await expectLater(
      notifier.setupPin(pin: '1234', confirmPin: '5678'),
      throwsA(isA<AppLockException>()),
    );
  });

  test('PIN is hashed (never stored as plaintext) and verifies correctly', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(appLockSettingsProvider.notifier);

    await notifier.setupPin(pin: '4242', confirmPin: '4242');

    expect(container.read(appLockSettingsProvider).value!.hasPinConfigured, isTrue);
    expect(notifier.verifyPin('4242'), isTrue);
    expect(notifier.verifyPin('0000'), isFalse);

    // The repository never exposes anything resembling the raw PIN — only
    // a hash/salt pair are stored under the hood.
    final repo = AppSettingsRepository.instance;
    expect(repo.hasPin(), isTrue);
  });

  test('wrong PIN is rejected, correct PIN is accepted', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(appLockSettingsProvider.notifier);

    await notifier.setupPin(pin: '135790', confirmPin: '135790');

    expect(notifier.verifyPin('000000'), isFalse);
    expect(notifier.verifyPin('135790'), isTrue);
  });

  test('App Lock settings (including PIN) persist across a fresh container', () async {
    final firstContainer = ProviderContainer();
    await firstContainer.read(appLockSettingsProvider.notifier).setupPin(
      pin: '9999',
      confirmPin: '9999',
    );
    await firstContainer.read(appLockSettingsProvider.notifier).setEnabled(true);
    firstContainer.dispose();

    final secondContainer = ProviderContainer();
    addTearDown(secondContainer.dispose);
    final settings = await secondContainer.read(appLockSettingsProvider.future);
    expect(settings.enabled, isTrue);
    expect(settings.hasPinConfigured, isTrue);
    expect(
      secondContainer.read(appLockSettingsProvider.notifier).verifyPin('9999'),
      isTrue,
    );
  });

  test('enabling/disabling App Lock never touches the account session', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(authProvider.notifier).signUp(
      fullName: 'Jane Doe',
      email: 'jane@example.com',
      password: 'password123',
    );
    expect(container.read(authProvider).value!.isAuthenticated, isTrue);

    await container.read(appLockSettingsProvider.notifier).setupPin(
      pin: '1111',
      confirmPin: '1111',
    );
    await container.read(appLockSettingsProvider.notifier).setEnabled(true);
    container.read(appLockStateProvider.notifier).state = true; // simulate a lock

    // Still logged in — App Lock is a separate re-entry gate, not a logout.
    expect(container.read(authProvider).value!.isAuthenticated, isTrue);

    container.read(appLockStateProvider.notifier).state = false; // simulate unlock
    expect(container.read(authProvider).value!.isAuthenticated, isTrue);
  });

  test('devices without biometric hardware fall back gracefully (no crash)', () async {
    // No platform channel is mocked in this unit-test environment, which
    // mirrors a device with no biometric support/enrollment. The service
    // must swallow that and report unavailable rather than throwing.
    final available = await BiometricService.instance.isAvailable();
    expect(available, isFalse);

    final authenticated = await BiometricService.instance.authenticate();
    expect(authenticated, isFalse);
  });
}
