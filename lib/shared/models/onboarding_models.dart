/// CONSUMER MONETIZATION FOUNDATION — PHASE 1/11/13. Pure Dart, zero
/// Flutter/Riverpod/Hive dependency. These answers are used ONLY to
/// improve which existing screens/cards are surfaced first (PHASE 11) —
/// never to alter any financial calculation.
library;

/// "What matters most to you?" — multi-select.
enum FinancialGoalPreference {
  controlSpending,
  saveMore,
  becomeDebtFree,
  buildEmergencyFund,
  reachGoals,
  understandFinances,
}

extension FinancialGoalPreferenceLabel on FinancialGoalPreference {
  String get label {
    switch (this) {
      case FinancialGoalPreference.controlSpending:
        return 'Control spending';
      case FinancialGoalPreference.saveMore:
        return 'Save more';
      case FinancialGoalPreference.becomeDebtFree:
        return 'Become debt-free';
      case FinancialGoalPreference.buildEmergencyFund:
        return 'Build an emergency fund';
      case FinancialGoalPreference.reachGoals:
        return 'Reach financial goals';
      case FinancialGoalPreference.understandFinances:
        return 'Understand my finances';
    }
  }
}

/// "How do you usually earn?" — single-select. Recorded for
/// presentation/prioritization ONLY — never used to fabricate an income
/// figure. Real income always comes from [UserProfile.monthlyIncome] or
/// real [Transaction] history, never from this answer.
enum IncomeSourceType { salary, business, freelance, multiple, other }

extension IncomeSourceTypeLabel on IncomeSourceType {
  String get label {
    switch (this) {
      case IncomeSourceType.salary:
        return 'Salary';
      case IncomeSourceType.business:
        return 'Business';
      case IncomeSourceType.freelance:
        return 'Freelance';
      case IncomeSourceType.multiple:
        return 'Multiple income sources';
      case IncomeSourceType.other:
        return 'Other';
    }
  }
}

/// PHASE 13 — "resume intelligently": which onboarding step a user should
/// land on, derived purely from what's already been persisted. Both
/// `SplashScreen` and `OnboardingScreen`'s "finish" handler consult this
/// SAME function rather than each guessing independently.
enum OnboardingStage { profile, goals, incomeSource, buildPicture, snapshot, ahaMoment, completed }

class OnboardingFlow {
  OnboardingFlow._();

  static OnboardingStage resumeStage({
    required bool profileExists,
    required bool goalsSet,
    required bool incomeSourceSet,
    required bool buildPictureAcknowledged,
    required bool snapshotViewed,
    required bool ahaMomentViewed,
  }) {
    if (!profileExists) return OnboardingStage.profile;
    if (!goalsSet) return OnboardingStage.goals;
    if (!incomeSourceSet) return OnboardingStage.incomeSource;
    if (!buildPictureAcknowledged) return OnboardingStage.buildPicture;
    if (!snapshotViewed) return OnboardingStage.snapshot;
    if (!ahaMomentViewed) return OnboardingStage.ahaMoment;
    return OnboardingStage.completed;
  }
}

/// PHASE 11 — a single, deterministic "what should this user see first"
/// derivation from their goal selections. Purely presentational: it never
/// changes what any calculator computes, only which already-existing
/// screens/cards a UI might choose to lead with. Kept as plain data (no
/// Flutter dependency) so it's unit-testable in isolation.
enum PrioritizedFocus { safeToSpend, debtPlanning, savingsAndGoals, general }

class OnboardingPersonalization {
  OnboardingPersonalization._();

  /// Deterministic priority order (first match wins) — mirrors the exact
  /// mapping given in the product spec. A user who selected multiple goals
  /// gets the highest-priority match; this never contradicts or recomputes
  /// any financial figure, it only picks which lens to lead with.
  static PrioritizedFocus focusFor(Set<FinancialGoalPreference> goals) {
    if (goals.contains(FinancialGoalPreference.controlSpending)) {
      return PrioritizedFocus.safeToSpend;
    }
    if (goals.contains(FinancialGoalPreference.becomeDebtFree)) {
      return PrioritizedFocus.debtPlanning;
    }
    if (goals.contains(FinancialGoalPreference.saveMore) ||
        goals.contains(FinancialGoalPreference.buildEmergencyFund) ||
        goals.contains(FinancialGoalPreference.reachGoals)) {
      return PrioritizedFocus.savingsAndGoals;
    }
    return PrioritizedFocus.general;
  }
}
