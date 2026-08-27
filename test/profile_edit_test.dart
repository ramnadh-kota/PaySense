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
import 'package:paysense/shared/repositories/user_profile_repository.dart';
import 'package:paysense/shared/services/account_scope.dart';

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
    tempDir = await Directory.systemTemp.createTemp('paysense_profile_edit_test');
    await _initHive(tempDir);
  });

  tearDown(() async {
    AccountScope.instance.deactivate();
    await Hive.deleteFromDisk();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  UserProfile fullProfile({
    String fullName = 'Jane Doe',
    String currency = 'INR',
    DateTime? createdAt,
  }) {
    final created = createdAt ?? DateTime(2026, 1, 1);
    return UserProfile(
      id: 'profile',
      fullName: fullName,
      email: 'jane@example.com',
      phone: '9876543210',
      dateOfBirth: DateTime(1995, 5, 20),
      gender: 'Female',
      occupation: 'Engineer',
      monthlyIncome: 50000,
      currency: currency,
      country: 'India',
      createdAt: created,
      updatedAt: created,
    );
  }

  test('existing profile values are fully retrievable for edit-form pre-fill', () async {
    await UserProfileRepository.instance.saveProfile(fullProfile());

    final loaded = await UserProfileRepository.instance.getProfile();
    expect(loaded, isNotNull);
    expect(loaded!.fullName, 'Jane Doe');
    expect(loaded.phone, '9876543210');
    expect(loaded.gender, 'Female');
    expect(loaded.occupation, 'Engineer');
    expect(loaded.monthlyIncome, 50000);
    expect(loaded.currency, 'INR');
    expect(loaded.country, 'India');
    expect(loaded.dateOfBirth, DateTime(1995, 5, 20));
  });

  test('editing updates fields while preserving id and original createdAt', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final original = fullProfile(createdAt: DateTime(2026, 1, 1));
    await container.read(userProfileProvider.notifier).saveProfile(original);

    // Mirrors what the fixed edit screen now does: same id/createdAt,
    // changed fields, fresh updatedAt.
    final edited = original.copyWith(
      fullName: 'Alex Doe',
      phone: '1112223333',
      updatedAt: DateTime(2026, 3, 1),
    );
    await container.read(userProfileProvider.notifier).saveProfile(edited);

    final persisted = await UserProfileRepository.instance.getProfile();
    expect(persisted!.id, 'profile');
    expect(persisted.createdAt, DateTime(2026, 1, 1));
    expect(persisted.fullName, 'Alex Doe');
    expect(persisted.phone, '1112223333');
  });

  test('provider state reflects the updated name immediately (Dashboard/Profile read this)', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(userProfileProvider.notifier).saveProfile(
      fullProfile(fullName: 'John'),
    );
    expect(container.read(userProfileProvider).value!.fullName, 'John');

    await container.read(userProfileProvider.notifier).saveProfile(
      fullProfile(fullName: 'Alex'),
    );
    expect(container.read(userProfileProvider).value!.fullName, 'Alex');
  });

  test('currency updates persist across a fresh provider container', () async {
    final firstContainer = ProviderContainer();
    await firstContainer.read(userProfileProvider.notifier).saveProfile(
      fullProfile(currency: 'USD'),
    );
    firstContainer.dispose();

    final secondContainer = ProviderContainer();
    addTearDown(secondContainer.dispose);
    final profile = await secondContainer.read(userProfileProvider.future);
    expect(profile!.currency, 'USD');
  });

  test('editing never creates a second profile record', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(userProfileProvider.notifier).saveProfile(fullProfile());
    await container.read(userProfileProvider.notifier).saveProfile(
      fullProfile(fullName: 'Updated Name'),
    );
    await container.read(userProfileProvider.notifier).saveProfile(
      fullProfile(fullName: 'Updated Again'),
    );

    final box = Hive.box<UserProfile>('user_profile');
    expect(box.length, 1);
    expect(box.get('profile')!.fullName, 'Updated Again');
  });

  test('editing the profile does not affect the authenticated session', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(authProvider.notifier).signUp(
      fullName: 'Jane Doe',
      email: 'jane@example.com',
      password: 'password123',
    );
    expect(container.read(authProvider).value!.isAuthenticated, isTrue);

    await container.read(userProfileProvider.notifier).saveProfile(
      fullProfile(fullName: 'Jane Updated'),
    );

    expect(container.read(authProvider).value!.isAuthenticated, isTrue);
    expect(
      container.read(authProvider).value!.account!.email,
      'jane@example.com',
    );
  });
}
