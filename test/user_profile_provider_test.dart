import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:paysense/features/ai/services/financial_context_builder.dart';
import 'package:paysense/shared/models/bill.dart';
import 'package:paysense/shared/models/budget.dart';
import 'package:paysense/shared/models/goal.dart';
import 'package:paysense/shared/models/recurring_transaction.dart';
import 'package:paysense/shared/models/transaction.dart';
import 'package:paysense/shared/models/user_profile.dart';
import 'package:paysense/shared/models/wallet.dart';
import 'package:paysense/shared/providers/app_settings_provider.dart';
import 'package:paysense/shared/providers/user_profile_provider.dart';
import 'package:paysense/shared/repositories/app_settings_repository.dart';
import 'package:paysense/shared/repositories/user_profile_repository.dart';

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

  await Hive.openBox<UserProfile>('user_profile');
  await Hive.openBox<Wallet>('wallets');
  await Hive.openBox<Transaction>('transactions');
  await Hive.openBox<Budget>('budgets');
  await Hive.openBox<Goal>('goals');
  await Hive.openBox<RecurringTransaction>('recurring_transactions');
  await Hive.openBox('app_settings');
  await Hive.openBox<Bill>('bills');
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('paysense_profile_test');
    await _initHive(tempDir);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('UserProfile model', () {
    test('toMap/fromMap round-trips all fields, including optional ones', () {
      final now = DateTime(2026, 1, 15, 9, 30);
      final dob = DateTime(1995, 6, 20);
      final profile = UserProfile(
        id: 'profile',
        fullName: 'Jane Doe',
        email: 'jane@example.com',
        phone: '9876543210',
        dateOfBirth: dob,
        gender: 'Female',
        occupation: 'Engineer',
        monthlyIncome: 75000,
        currency: 'USD',
        country: 'United States',
        monthlyEmi: 5000,
        savingsGoal: 20000,
        createdAt: now,
        updatedAt: now,
      );

      final restored = UserProfile.fromMap(profile.toMap());

      expect(restored, profile);
      expect(restored.dateOfBirth, dob);
    });

    test('fromMap defaults optional fields when absent', () {
      final now = DateTime(2026, 1, 15);
      final minimalMap = <String, dynamic>{
        'id': 'profile',
        'fullName': 'Jane Doe',
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      };

      final profile = UserProfile.fromMap(minimalMap);

      expect(profile.fullName, 'Jane Doe');
      expect(profile.email, '');
      expect(profile.phone, '');
      expect(profile.dateOfBirth, isNull);
      expect(profile.gender, '');
      expect(profile.occupation, '');
      expect(profile.monthlyIncome, 0.0);
      expect(profile.currency, 'INR');
      expect(profile.country, 'India');
      expect(profile.monthlyEmi, 0.0);
      expect(profile.savingsGoal, 0.0);
    });
  });

  test(
    'UserProfileRepository saves and retrieves a profile, and clears it',
    () async {
      final now = DateTime.now();
      final profile = UserProfile(
        id: 'profile',
        fullName: 'Alex Kumar',
        monthlyIncome: 60000,
        createdAt: now,
        updatedAt: now,
      );

      expect(await UserProfileRepository.instance.getProfile(), isNull);

      await UserProfileRepository.instance.saveProfile(profile);
      final stored = await UserProfileRepository.instance.getProfile();
      expect(stored, isNotNull);
      expect(stored!.fullName, 'Alex Kumar');
      expect(stored.monthlyIncome, 60000.0);

      await UserProfileRepository.instance.clearProfile();
      expect(await UserProfileRepository.instance.getProfile(), isNull);
    },
  );

  test(
    'userProfileProvider.saveProfile persists to Hive and resolves to AsyncData',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final initial = await container
          .read(userProfileProvider.future)
          .timeout(const Duration(seconds: 5));
      expect(initial, isNull);

      final now = DateTime.now();
      await container
          .read(userProfileProvider.notifier)
          .saveProfile(
            UserProfile(
              id: 'profile',
              fullName: 'Priya Shah',
              createdAt: now,
              updatedAt: now,
            ),
          )
          .timeout(const Duration(seconds: 5));

      final state = container.read(userProfileProvider);
      expect(state.hasValue, isTrue);
      expect(state.value!.fullName, 'Priya Shah');
    },
  );

  group('AppSettingsRepository / isFirstLaunchProvider', () {
    test('isFirstLaunch defaults to true and flips after completion', () async {
      expect(await AppSettingsRepository.instance.isFirstLaunch(), isTrue);

      await AppSettingsRepository.instance.completeFirstLaunch();

      expect(await AppSettingsRepository.instance.isFirstLaunch(), isFalse);
    });

    test(
      'isFirstLaunchProvider reflects repository state and completeFirstLaunch',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final initial = await container
            .read(isFirstLaunchProvider.future)
            .timeout(const Duration(seconds: 5));
        expect(initial, isTrue);

        await container
            .read(isFirstLaunchProvider.notifier)
            .completeFirstLaunch()
            .timeout(const Duration(seconds: 5));

        final state = container.read(isFirstLaunchProvider);
        expect(state.value, isFalse);
      },
    );
  });

  test(
    'FinancialContextBuilder includes profile fields (name, income, emi, savings)',
    () async {
      final now = DateTime.now();
      await UserProfileRepository.instance.saveProfile(
        UserProfile(
          id: 'profile',
          fullName: 'Meera Nair',
          monthlyIncome: 90000,
          monthlyEmi: 12000,
          savingsGoal: 15000,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final context = await FinancialContextBuilder.instance.build();

      expect(context.fullName, 'Meera Nair');
      expect(context.monthlyIncome, 90000.0);
      expect(context.monthlyEmi, 12000.0);
      expect(context.savingsGoal, 15000.0);
    },
  );
}
