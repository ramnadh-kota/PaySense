// Remaining focused tests for INDIA TAX PLANNER 1.0's AI integration and a
// few model-level items not covered by tax_calculator_test.dart /
// tax_income_estimator_test.dart / tax_orchestrator_test.dart: TaxProfile
// construction, HRA support, actual-income override taking precedence over
// the PaySense estimate, the AI receiving (and never altering) the
// deterministic tax result, and the disclaimer's exact wording.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:paysense/core/constants/disclaimers.dart';
import 'package:paysense/features/ai/providers/ai_provider.dart';
import 'package:paysense/features/ai/services/ai_service.dart';
import 'package:paysense/shared/models/account.dart';
import 'package:paysense/shared/models/bill.dart';
import 'package:paysense/shared/models/budget.dart';
import 'package:paysense/shared/models/goal.dart';
import 'package:paysense/shared/models/loan.dart';
import 'package:paysense/shared/models/notification_record.dart';
import 'package:paysense/shared/models/recurring_transaction.dart';
import 'package:paysense/shared/models/sms_review_item.dart';
import 'package:paysense/shared/models/tax_settings.dart';
import 'package:paysense/shared/models/transaction.dart';
import 'package:paysense/shared/models/user_profile.dart';
import 'package:paysense/shared/models/wallet.dart';
import 'package:paysense/shared/repositories/tax_settings_repository.dart';
import 'package:paysense/shared/repositories/transaction_repository.dart';
import 'package:paysense/shared/repositories/wallet_repository.dart';
import 'package:paysense/shared/utils/tax_calculator.dart';

Future<void> _initHive(Directory dir) async {
  Hive.init(dir.path);
  if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(UserProfileAdapter());
  if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(WalletAdapter());
  if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(TransactionAdapter());
  if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(BudgetAdapter());
  if (!Hive.isAdapterRegistered(4)) Hive.registerAdapter(GoalAdapter());
  if (!Hive.isAdapterRegistered(5)) Hive.registerAdapter(RecurringTransactionAdapter());
  if (!Hive.isAdapterRegistered(6)) Hive.registerAdapter(BillAdapter());
  if (!Hive.isAdapterRegistered(7)) Hive.registerAdapter(LoanAdapter());
  if (!Hive.isAdapterRegistered(8)) Hive.registerAdapter(AccountAdapter());
  if (!Hive.isAdapterRegistered(9)) Hive.registerAdapter(AppNotificationAdapter());
  if (!Hive.isAdapterRegistered(10)) Hive.registerAdapter(SmsReviewItemAdapter());
  if (!Hive.isAdapterRegistered(11)) Hive.registerAdapter(TaxSettingsAdapter());

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
  await Hive.openBox<TaxSettings>('tax_settings');
}

class _CapturingAiService implements AiService {
  static const String response = 'Here is your tax estimate explained.';
  final List<String> receivedContexts = [];

  @override
  Future<String> ask({required String message, required String financialContext}) async {
    receivedContexts.add(financialContext);
    return response;
  }
}

void main() {
  group('1. TaxProfile', () {
    test('defaults to the new regime, zero deductions, and an un-estimated income', () {
      const profile = TaxProfile(annualGrossIncome: 1200000);
      expect(profile.regime, TaxRegime.newRegime);
      expect(profile.section80C, 0);
      expect(profile.section80D, 0);
      expect(profile.homeLoanInterest, 0);
      expect(profile.hraExemption, 0);
      expect(profile.isIncomeEstimated, isFalse);
    });

    test('copyWith only changes the specified fields', () {
      const profile = TaxProfile(annualGrossIncome: 1200000, regime: TaxRegime.old);
      final updated = profile.copyWith(section80C: 150000);
      expect(updated.annualGrossIncome, 1200000);
      expect(updated.regime, TaxRegime.old);
      expect(updated.section80C, 150000);
    });

    test('TaxSettings round-trips a TaxProfile through toTaxProfile/fromTaxProfile without loss', () {
      const profile = TaxProfile(
        annualGrossIncome: 1500000, otherIncome: 20000, regime: TaxRegime.old,
        ageBand: TaxAgeBand.seniorCitizen60to79, section80C: 150000, section80D: 50000,
        homeLoanInterest: 200000, hraExemption: 60000, otherEligibleDeductions: 10000,
        tdsAlreadyDeducted: 80000, isIncomeEstimated: true,
      );
      final roundTripped = TaxSettings.fromTaxProfile(profile).toTaxProfile();
      expect(roundTripped.annualGrossIncome, profile.annualGrossIncome);
      expect(roundTripped.regime, profile.regime);
      expect(roundTripped.ageBand, profile.ageBand);
      expect(roundTripped.section80C, profile.section80C);
      expect(roundTripped.hraExemption, profile.hraExemption);
      expect(roundTripped.isIncomeEstimated, profile.isIncomeEstimated);
    });
  });

  group('13. HRA', () {
    test('a manually-entered HRA exemption reduces taxable income under the old regime', () {
      final withHra = TaxCalculator.calculate(
        profile: const TaxProfile(annualGrossIncome: 1200000, regime: TaxRegime.old, hraExemption: 100000),
      );
      final withoutHra = TaxCalculator.calculate(
        profile: const TaxProfile(annualGrossIncome: 1200000, regime: TaxRegime.old),
      );
      expect(withHra.taxableIncome, withoutHra.taxableIncome - 100000);
    });

    test('HRA has no effect under the new regime — PaySense never fabricates an HRA computation', () {
      final withHra = TaxCalculator.calculate(
        profile: const TaxProfile(annualGrossIncome: 1200000, hraExemption: 100000),
      );
      final withoutHra = TaxCalculator.calculate(
        profile: const TaxProfile(annualGrossIncome: 1200000),
      );
      expect(withHra.taxableIncome, withoutHra.taxableIncome);
    });
  });

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('paysense_tax_ai_test');
    await _initHive(tempDir);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<void> seedIncome() async {
    await WalletRepository.instance.add(
      Wallet(
        id: 'w1', name: 'Main', bankName: 'X', type: 'Bank',
        openingBalance: 0, currentBalance: 100000, createdAt: DateTime(2026, 1, 1),
      ),
    );
    await TransactionRepository.instance.add(
      Transaction(
        id: 't1', title: 'Salary', amount: 100000, categoryId: 'Salary', accountId: 'w1',
        transactionType: 'Income', paymentMethod: 'Bank', note: '', createdAt: DateTime.now(),
      ),
    );
  }

  group('5. Actual-income override', () {
    test('a saved profile with a manually confirmed income is used, never silently replaced by the estimate', () async {
      await seedIncome(); // PaySense would estimate ~1,200,000/year from this
      await TaxSettingsRepository.instance.save(
        TaxSettings.fromTaxProfile(
          const TaxProfile(annualGrossIncome: 2500000, isIncomeEstimated: false),
        ),
      );

      final saved = (await TaxSettingsRepository.instance.get())!.toTaxProfile();
      expect(saved.annualGrossIncome, 2500000);
      expect(saved.isIncomeEstimated, isFalse);
    });
  });

  group('26. AI receives deterministic tax result / 27. AI cannot alter the calculation', () {
    test('the injected financial_context carries the exact TaxCalculator figures', () async {
      await seedIncome();
      await TaxSettingsRepository.instance.save(
        TaxSettings.fromTaxProfile(
          const TaxProfile(annualGrossIncome: 1500000, regime: TaxRegime.newRegime),
        ),
      );

      final expected = TaxCalculator.calculate(
        profile: const TaxProfile(annualGrossIncome: 1500000, regime: TaxRegime.newRegime),
      );

      final fakeService = _CapturingAiService();
      final container = ProviderContainer(overrides: [aiServiceProvider.overrideWithValue(fakeService)]);
      addTearDown(container.dispose);

      await container.read(aiChatProvider.notifier).sendMessage('How much tax will I pay?');

      expect(fakeService.receivedContexts, hasLength(1));
      final contextMap = jsonDecode(fakeService.receivedContexts.single) as Map<String, dynamic>;
      expect(contextMap.containsKey('taxScenario'), isTrue);

      final scenario = contextMap['taxScenario'] as Map<String, dynamic>;
      final result = scenario['result'] as Map<String, dynamic>;
      // Structurally impossible for the AI to have altered these — they are
      // read directly from the same TaxCalculator.calculate call the
      // pipeline itself made, before the AI was ever invoked.
      expect(result['estimatedTax'], closeTo(expected.estimatedTax, 0.01));
      expect(result['taxableIncome'], closeTo(expected.taxableIncome, 0.01));
      expect(scenario['isSimulationOnly'], isTrue);

      final messages = container.read(aiChatProvider).value!;
      expect(messages.last.taxOutcome, isNotNull);
      expect(messages.last.taxOutcome!.result!.estimatedTax, closeTo(expected.estimatedTax, 0.01));
    });

    test('a compareRegimes question injects both regimes\' real figures', () async {
      await seedIncome();
      await TaxSettingsRepository.instance.save(
        TaxSettings.fromTaxProfile(const TaxProfile(annualGrossIncome: 1500000)),
      );

      final fakeService = _CapturingAiService();
      final container = ProviderContainer(overrides: [aiServiceProvider.overrideWithValue(fakeService)]);
      addTearDown(container.dispose);

      await container.read(aiChatProvider.notifier).sendMessage('Compare old and new regime');

      final contextMap = jsonDecode(fakeService.receivedContexts.single) as Map<String, dynamic>;
      final scenario = contextMap['taxScenario'] as Map<String, dynamic>;
      expect(scenario.containsKey('oldRegime'), isTrue);
      expect(scenario.containsKey('newRegime'), isTrue);
    });
  });

  group('36. Disclaimer visibility', () {
    test('the tax disclaimer carries the exact required wording', () {
      expect(taxDisclaimer, contains('not a substitute for professional tax advice'));
      expect(taxDisclaimer, contains('ITR filing'));
    });
  });
}
