// Pure tests for OnboardingFlow.resumeStage / OnboardingPersonalization
// (Consumer Monetization Foundation, PHASE 1/11/13/16 items 1/16).
import 'package:flutter_test/flutter_test.dart';
import 'package:paysense/shared/models/onboarding_models.dart';

void main() {
  group('1/13. Onboarding state / resume logic', () {
    test('no profile yet -> resumes at profile', () {
      expect(
        OnboardingFlow.resumeStage(
          profileExists: false, goalsSet: false, incomeSourceSet: false,
          buildPictureAcknowledged: false, snapshotViewed: false, ahaMomentViewed: false,
        ),
        OnboardingStage.profile,
      );
    });

    test('profile saved, nothing else -> resumes at goals', () {
      expect(
        OnboardingFlow.resumeStage(
          profileExists: true, goalsSet: false, incomeSourceSet: false,
          buildPictureAcknowledged: false, snapshotViewed: false, ahaMomentViewed: false,
        ),
        OnboardingStage.goals,
      );
    });

    test('goals set -> resumes at income source', () {
      expect(
        OnboardingFlow.resumeStage(
          profileExists: true, goalsSet: true, incomeSourceSet: false,
          buildPictureAcknowledged: false, snapshotViewed: false, ahaMomentViewed: false,
        ),
        OnboardingStage.incomeSource,
      );
    });

    test('income source set -> resumes at build picture', () {
      expect(
        OnboardingFlow.resumeStage(
          profileExists: true, goalsSet: true, incomeSourceSet: true,
          buildPictureAcknowledged: false, snapshotViewed: false, ahaMomentViewed: false,
        ),
        OnboardingStage.buildPicture,
      );
    });

    test('build picture acknowledged -> resumes at snapshot', () {
      expect(
        OnboardingFlow.resumeStage(
          profileExists: true, goalsSet: true, incomeSourceSet: true,
          buildPictureAcknowledged: true, snapshotViewed: false, ahaMomentViewed: false,
        ),
        OnboardingStage.snapshot,
      );
    });

    test('snapshot viewed -> resumes at aha moment', () {
      expect(
        OnboardingFlow.resumeStage(
          profileExists: true, goalsSet: true, incomeSourceSet: true,
          buildPictureAcknowledged: true, snapshotViewed: true, ahaMomentViewed: false,
        ),
        OnboardingStage.ahaMoment,
      );
    });

    test('everything done -> completed', () {
      expect(
        OnboardingFlow.resumeStage(
          profileExists: true, goalsSet: true, incomeSourceSet: true,
          buildPictureAcknowledged: true, snapshotViewed: true, ahaMomentViewed: true,
        ),
        OnboardingStage.completed,
      );
    });

    test('a completed step never regresses earlier stages when a LATER one is also done', () {
      // Simulates the exact "resume intelligently" scenario: profile and
      // goals already saved, everything after is not — must land on
      // incomeSource, not restart from profile.
      expect(
        OnboardingFlow.resumeStage(
          profileExists: true, goalsSet: true, incomeSourceSet: false,
          buildPictureAcknowledged: false, snapshotViewed: false, ahaMomentViewed: false,
        ),
        OnboardingStage.incomeSource,
      );
    });
  });

  group('16. Onboarding personalization never touches financial calculations', () {
    test('"Control spending" prioritizes Safe-to-Spend', () {
      expect(
        OnboardingPersonalization.focusFor({FinancialGoalPreference.controlSpending}),
        PrioritizedFocus.safeToSpend,
      );
    });

    test('"Become debt-free" prioritizes debt planning', () {
      expect(
        OnboardingPersonalization.focusFor({FinancialGoalPreference.becomeDebtFree}),
        PrioritizedFocus.debtPlanning,
      );
    });

    test('"Save more" prioritizes savings and goals', () {
      expect(
        OnboardingPersonalization.focusFor({FinancialGoalPreference.saveMore}),
        PrioritizedFocus.savingsAndGoals,
      );
    });

    test('"Build an emergency fund" also prioritizes savings and goals', () {
      expect(
        OnboardingPersonalization.focusFor({FinancialGoalPreference.buildEmergencyFund}),
        PrioritizedFocus.savingsAndGoals,
      );
    });

    test('no selection at all falls back to general, never crashes', () {
      expect(OnboardingPersonalization.focusFor(const {}), PrioritizedFocus.general);
    });

    test('when multiple goals are selected, the highest-priority match wins deterministically', () {
      expect(
        OnboardingPersonalization.focusFor({
          FinancialGoalPreference.saveMore,
          FinancialGoalPreference.controlSpending,
        }),
        PrioritizedFocus.safeToSpend,
      );
    });

    test('"Understand my finances" alone falls back to general (no dedicated lens)', () {
      expect(
        OnboardingPersonalization.focusFor({FinancialGoalPreference.understandFinances}),
        PrioritizedFocus.general,
      );
    });
  });

  group('Labels', () {
    test('every FinancialGoalPreference has a non-empty label', () {
      for (final g in FinancialGoalPreference.values) {
        expect(g.label, isNotEmpty);
      }
    });

    test('every IncomeSourceType has a non-empty label', () {
      for (final i in IncomeSourceType.values) {
        expect(i.label, isNotEmpty);
      }
    });
  });
}
