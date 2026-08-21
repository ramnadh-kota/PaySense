import 'package:paysense/features/ai/models/tax_outcome.dart';
import 'package:paysense/features/ai/services/tax_intent_parser.dart';
import 'package:paysense/shared/repositories/tax_settings_repository.dart';
import 'package:paysense/shared/repositories/transaction_repository.dart';
import 'package:paysense/shared/utils/tax_calculator.dart';
import 'package:paysense/shared/utils/tax_income_estimator.dart';

const String _noIncomeAtAllMessage =
    'I need your annual income before I can estimate your tax.';

const String _regimeChoicePrompt =
    'I can estimate that. I have your PaySense income history, but I don\'t '
    'have your tax deductions.\n\nWould you like me to compare:\n'
    '1. New Regime\n2. Old Regime\n3. Both?';

/// Stage B of the tax pipeline (PHASE 10/11/12) — resolves a [TaxIntent]
/// against the user's saved [TaxProfile] (if any) and PaySense's own income
/// estimate (PHASE 3), then hands off to [TaxCalculator] for the actual
/// arithmetic. Like [WhatIfOrchestrator], this class only resolves/wires —
/// it never computes tax itself.
class TaxOrchestrator {
  TaxOrchestrator._();

  static final TaxOrchestrator instance = TaxOrchestrator._();

  Future<TaxOutcome> resolve(TaxIntent intent, {DateTime? now}) async {
    if (!intent.isActionable) return TaxOutcome.none();

    final referenceNow = now ?? DateTime.now();
    final savedSettings = await TaxSettingsRepository.instance.get();
    final savedProfile = savedSettings?.toTaxProfile();

    final TaxProfile resolvedProfile;
    if (savedProfile != null && savedProfile.annualGrossIncome > 0) {
      resolvedProfile = savedProfile;
    } else {
      final transactions = await TransactionRepository.instance.getAll();
      final estimate = TaxIncomeEstimator.estimate(transactions, referenceNow);
      if (!estimate.hasIncomeData) {
        return TaxOutcome.notFound(_noIncomeAtAllMessage);
      }
      resolvedProfile = TaxProfile(
        annualGrossIncome: estimate.estimatedAnnualIncome,
        isIncomeEstimated: true,
      );
    }

    switch (intent.type) {
      case TaxIntentType.estimate:
        return _resolveEstimate(intent, resolvedProfile, hasSavedProfile: savedProfile != null, now: referenceNow);
      case TaxIntentType.monthlyProvision:
        return TaxOutcome.calculated(
          TaxCalculator.calculate(profile: resolvedProfile, now: referenceNow),
        );
      case TaxIntentType.compareRegimes:
        return TaxOutcome.comparison(
          TaxCalculator.compareRegimes(profile: resolvedProfile, now: referenceNow),
        );
      case TaxIntentType.whatIfSalary:
        return _resolveWhatIf(
          intent: intent,
          baseProfile: resolvedProfile,
          now: referenceNow,
          clarificationPrompt: 'What would the new annual salary be?',
          entityLabel: 'Salary change',
          applyHypothetical: (profile, amount) => profile.copyWith(annualGrossIncome: amount),
          forceOldRegime: false,
        );
      case TaxIntentType.whatIf80C:
        return _resolveWhatIf(
          intent: intent,
          baseProfile: resolvedProfile,
          now: referenceNow,
          clarificationPrompt: 'How much would you like to invest under 80C?',
          entityLabel: 'Section 80C',
          applyHypothetical: (profile, amount) => profile.copyWith(section80C: amount),
          forceOldRegime: true,
        );
      case TaxIntentType.whatIf80D:
        return _resolveWhatIf(
          intent: intent,
          baseProfile: resolvedProfile,
          now: referenceNow,
          clarificationPrompt: 'How much would you like to claim under 80D?',
          entityLabel: 'Section 80D',
          applyHypothetical: (profile, amount) => profile.copyWith(section80D: amount),
          forceOldRegime: true,
        );
      case TaxIntentType.whatIfHomeLoanInterest:
        return _resolveWhatIf(
          intent: intent,
          baseProfile: resolvedProfile,
          now: referenceNow,
          clarificationPrompt: 'How much home-loan interest would you like to claim?',
          entityLabel: 'Home loan interest',
          applyHypothetical: (profile, amount) => profile.copyWith(homeLoanInterest: amount),
          forceOldRegime: true,
        );
      case TaxIntentType.none:
        return TaxOutcome.none();
    }
  }

  TaxOutcome _resolveEstimate(
    TaxIntent intent,
    TaxProfile resolvedProfile, {
    required bool hasSavedProfile,
    required DateTime now,
  }) {
    if (intent.regimeChoice == TaxIntentRegimeChoice.both) {
      return TaxOutcome.comparison(TaxCalculator.compareRegimes(profile: resolvedProfile, now: now));
    }
    if (intent.regimeChoice == TaxIntentRegimeChoice.newRegime) {
      return TaxOutcome.calculated(
        TaxCalculator.calculate(profile: resolvedProfile.copyWith(regime: TaxRegime.newRegime), now: now),
      );
    }
    if (intent.regimeChoice == TaxIntentRegimeChoice.old) {
      return TaxOutcome.calculated(
        TaxCalculator.calculate(profile: resolvedProfile.copyWith(regime: TaxRegime.old), now: now),
      );
    }
    // No explicit regime named in the question. If the user already has a
    // saved profile (with its own regime choice), just use it — only ask
    // PHASE 12's clarification when there's truly no regime preference on
    // record yet.
    if (hasSavedProfile) {
      return TaxOutcome.calculated(TaxCalculator.calculate(profile: resolvedProfile, now: now));
    }
    return TaxOutcome.clarification(_regimeChoicePrompt);
  }

  TaxOutcome _resolveWhatIf({
    required TaxIntent intent,
    required TaxProfile baseProfile,
    required DateTime now,
    required String clarificationPrompt,
    required String entityLabel,
    required TaxProfile Function(TaxProfile profile, double amount) applyHypothetical,
    required bool forceOldRegime,
  }) {
    final amount = intent.amount;
    if (amount == null) {
      return TaxOutcome.clarification(clarificationPrompt);
    }

    // 80C/80D/home-loan-interest deductions only exist under the old
    // regime — forcing it here (rather than guessing the user meant their
    // saved new-regime profile) is what makes the scenario meaningful at
    // all instead of silently computing a no-op.
    final baseline = forceOldRegime ? baseProfile.copyWith(regime: TaxRegime.old) : baseProfile;
    final hypothetical = applyHypothetical(baseline, amount);

    return TaxOutcome.calculated(
      TaxCalculator.calculate(profile: hypothetical, now: now),
      beforeResult: TaxCalculator.calculate(profile: baseline, now: now),
      entityLabel: entityLabel,
    );
  }
}
