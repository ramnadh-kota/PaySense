import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/tax_settings.dart';
import '../models/transaction.dart';
import '../repositories/tax_settings_repository.dart';
import '../utils/tax_calculator.dart';
import '../utils/tax_income_estimator.dart';
import 'transaction_provider.dart';

final taxSettingsRepositoryProvider = Provider<TaxSettingsRepository>((ref) {
  return TaxSettingsRepository.instance;
});

/// PHASE 3 — PaySense's own income-history estimate. Always computable
/// (never depends on a saved [TaxProfile]) so the Tax Planner screen has a
/// starting point to show before the user has entered anything — but it
/// must always be labelled as an estimate, never presented as the user's
/// confirmed actual income (see PHASE 3 / PHASE 19).
final taxIncomeEstimateProvider = Provider<IncomeEstimate>((ref) {
  final transactions = ref.watch(transactionsProvider).value ?? const <Transaction>[];
  return TaxIncomeEstimator.estimate(transactions, DateTime.now());
});

/// The user's saved tax profile (PHASE 2/13) — null until they've entered
/// and saved anything, matching PHASE 19's "no tax profile yet" empty
/// state. Never auto-created from the income estimate alone; only
/// [TaxProfileNotifier.save] (an explicit user action) persists one.
final taxProfileProvider = AsyncNotifierProvider<TaxProfileNotifier, TaxProfile?>(
  TaxProfileNotifier.new,
);

class TaxProfileNotifier extends AsyncNotifier<TaxProfile?> {
  @override
  Future<TaxProfile?> build() async {
    final saved = await ref.watch(taxSettingsRepositoryProvider).get();
    return saved?.toTaxProfile();
  }

  Future<void> save(TaxProfile profile) async {
    final repo = ref.read(taxSettingsRepositoryProvider);
    await repo.save(TaxSettings.fromTaxProfile(profile));
    state = AsyncData(profile);
  }

  Future<void> clear() async {
    final repo = ref.read(taxSettingsRepositoryProvider);
    await repo.clear();
    state = const AsyncData(null);
  }
}

/// The current deterministic calculation for the saved profile, or null
/// when there's no profile yet / no income to calculate from — the
/// PHASE 19 empty state the screen/AI must handle explicitly rather than
/// showing a fabricated ₹0 result.
final taxCalculationProvider = Provider<TaxCalculationResult?>((ref) {
  final profile = ref.watch(taxProfileProvider).value;
  if (profile == null || profile.annualGrossIncome <= 0) return null;
  return TaxCalculator.calculate(profile: profile);
});

/// PHASE 6 — old vs new regime comparison for the saved profile.
final taxRegimeComparisonProvider = Provider<TaxRegimeComparisonResult?>((ref) {
  final profile = ref.watch(taxProfileProvider).value;
  if (profile == null || profile.annualGrossIncome <= 0) return null;
  return TaxCalculator.compareRegimes(profile: profile);
});
