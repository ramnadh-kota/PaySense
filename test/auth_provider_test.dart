import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:paysense/shared/models/account.dart';
import 'package:paysense/shared/models/bill.dart';
import 'package:paysense/shared/models/budget.dart';
import 'package:paysense/shared/models/goal.dart';
import 'package:paysense/shared/models/loan.dart';
import 'package:paysense/shared/models/recurring_transaction.dart';
import 'package:paysense/shared/models/transaction.dart';
import 'package:paysense/shared/models/user_profile.dart';
import 'package:paysense/shared/models/wallet.dart';
import 'package:paysense/shared/providers/auth_provider.dart';
import 'package:paysense/shared/providers/user_profile_provider.dart';
import 'package:paysense/shared/repositories/account_repository.dart';
import 'package:paysense/shared/repositories/auth_session_repository.dart';
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
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('paysense_auth_test');
    await _initHive(tempDir);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('build() starts unauthenticated when no session exists', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final state = await container.read(authProvider.future);
    expect(state.isAuthenticated, isFalse);
    expect(state.account, isNull);
  });

  test('signUp creates an account, starts a session, and never stores the '
      'plaintext password', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(authProvider.notifier).signUp(
      fullName: 'Jane Doe',
      email: 'Jane@Example.com',
      password: 'password123',
    );

    final state = container.read(authProvider).value!;
    expect(state.isAuthenticated, isTrue);
    expect(state.account!.email, 'jane@example.com');
    expect(state.account!.passwordHash, isNot('password123'));
    expect(state.account!.passwordHash, isNotEmpty);

    expect(AuthSessionRepository.instance.currentEmail(), 'jane@example.com');
  });

  test('signUp creates the shared UserProfile when none exists', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(authProvider.notifier).signUp(
      fullName: 'Jane Doe',
      email: 'jane@example.com',
      password: 'password123',
    );

    final profile = await container.read(userProfileProvider.future);
    expect(profile, isNotNull);
    expect(profile!.fullName, 'Jane Doe');
    expect(profile.email, 'jane@example.com');
  });

  test('signUp does not overwrite an existing UserProfile', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final now = DateTime.now();
    await container.read(userProfileProvider.notifier).saveProfile(
      UserProfile(
        id: 'profile',
        fullName: 'Existing Name',
        phone: '9876543210',
        createdAt: now,
        updatedAt: now,
      ),
    );

    await container.read(authProvider.notifier).signUp(
      fullName: 'Jane Doe',
      email: 'jane@example.com',
      password: 'password123',
    );

    final profile = await container.read(userProfileProvider.future);
    expect(profile!.fullName, 'Existing Name');
    expect(profile.phone, '9876543210');
  });

  test('signUp rejects a duplicate email', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(authProvider.notifier).signUp(
      fullName: 'Jane Doe',
      email: 'jane@example.com',
      password: 'password123',
    );

    await expectLater(
      container.read(authProvider.notifier).signUp(
        fullName: 'Someone Else',
        email: 'jane@example.com',
        password: 'anotherpass',
      ),
      throwsA(isA<AuthException>()),
    );
  });

  test('login succeeds with correct credentials and fails with wrong '
      'password', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    const salt = 'fixed-test-salt';
    await AccountRepository.instance.add(
      Account(
        id: 'acc1',
        email: 'jane@example.com',
        fullName: 'Jane Doe',
        passwordHash: PasswordHasher.hash('correct-password', salt),
        passwordSalt: salt,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    await expectLater(
      container.read(authProvider.notifier).login(
        email: 'jane@example.com',
        password: 'wrong-password',
      ),
      throwsA(isA<AuthException>()),
    );
    expect(container.read(authProvider).value!.isAuthenticated, isFalse);

    await container.read(authProvider.notifier).login(
      email: 'jane@example.com',
      password: 'correct-password',
    );
    expect(container.read(authProvider).value!.isAuthenticated, isTrue);
  });

  test('logout clears the session but preserves the account and profile', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(authProvider.notifier).signUp(
      fullName: 'Jane Doe',
      email: 'jane@example.com',
      password: 'password123',
    );

    await container.read(authProvider.notifier).logout();

    final state = container.read(authProvider).value!;
    expect(state.isAuthenticated, isFalse);
    expect(AuthSessionRepository.instance.currentEmail(), isNull);

    expect(await AccountRepository.instance.exists('jane@example.com'), isTrue);
    final profile = await container.read(userProfileProvider.future);
    expect(profile, isNotNull);
  });

  test('a fresh AuthNotifier rehydrates the session after a restart', () async {
    final firstContainer = ProviderContainer();
    await firstContainer.read(authProvider.notifier).signUp(
      fullName: 'Jane Doe',
      email: 'jane@example.com',
      password: 'password123',
    );
    firstContainer.dispose();

    final secondContainer = ProviderContainer();
    addTearDown(secondContainer.dispose);

    final state = await secondContainer.read(authProvider.future);
    expect(state.isAuthenticated, isTrue);
    expect(state.account!.email, 'jane@example.com');
  });
}
