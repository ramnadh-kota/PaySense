// Consumer Monetization Foundation — PHASE 16 items 9/10/16: route
// registration, paywall navigation, centralized entitlement usage (never a
// bespoke per-feature check), and Dashboard/returning-user wiring. Mirrors
// the established source-inspection pattern used by
// financial_timeline_integration_test.dart / compare_periods_integration_test.dart.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:paysense/core/routes/app_routes.dart';

void main() {
  group('Route registration', () {
    late String routerSource;

    setUpAll(() async {
      routerSource = await File('lib/core/routes/app_router.dart').readAsString();
    });

    test('all 6 new routes are registered with real constants (not string literals)', () {
      final routes = <String, String>{
        'AppRoutes.onboardingGoals': 'OnboardingGoalsScreen',
        'AppRoutes.onboardingIncomeSource': 'OnboardingIncomeSourceScreen',
        'AppRoutes.onboardingBuildPicture': 'OnboardingBuildPictureScreen',
        'AppRoutes.financialSnapshot': 'FinancialSnapshotScreen',
        'AppRoutes.ahaMoment': 'AhaMomentScreen',
        'AppRoutes.paywall': 'PaywallScreen',
      };
      for (final entry in routes.entries) {
        expect(routerSource.contains('case ${entry.key}:'), isTrue, reason: '${entry.key} not registered');
        expect(routerSource.contains(entry.value), isTrue, reason: '${entry.value} not wired to its route');
      }
    });

    test('route path constants match the expected URL-style strings', () {
      expect(AppRoutes.onboardingGoals, '/onboarding-goals');
      expect(AppRoutes.onboardingIncomeSource, '/onboarding-income-source');
      expect(AppRoutes.onboardingBuildPicture, '/onboarding-build-picture');
      expect(AppRoutes.financialSnapshot, '/financial-snapshot');
      expect(AppRoutes.ahaMoment, '/aha-moment');
      expect(AppRoutes.paywall, '/paywall');
    });
  });

  group('9/10. Paywall navigation — centralized via PremiumDiscoveryBanner', () {
    late String bannerSource;
    late String aiScreenSource;
    late String affordabilitySource;
    late String taxPlannerSource;

    setUpAll(() async {
      bannerSource = await File('lib/shared/widgets/premium_discovery_banner.dart').readAsString();
      aiScreenSource = await File('lib/features/ai/ai_screen.dart').readAsString();
      affordabilitySource = await File('lib/features/affordability/presentation/affordability_screen.dart').readAsString();
      taxPlannerSource = await File('lib/features/tax/presentation/tax_planner_screen.dart').readAsString();
    });

    test('the shared premium discovery banner navigates to AppRoutes.paywall (real constant)', () {
      expect(bannerSource.contains('Navigator.of(context).pushNamed(AppRoutes.paywall)'), isTrue);
      expect(bannerSource.contains("'/paywall'"), isFalse);
    });

    test('AI/Affordability/Tax Planner screens each gate their discovery banner through '
        'canAccessEntitlement — never a bespoke tier check', () {
      for (final source in [aiScreenSource, affordabilitySource, taxPlannerSource]) {
        expect(source.contains('canAccessEntitlement(ref,'), isTrue);
        // No screen should ever compare a tier directly — that would be a
        // bespoke check bypassing the centralized service.
        expect(source.contains('== PlanTier.free') || source.contains('== PlanTier.plus'), isFalse);
      }
    });

    test('the existing AI chat/Affordability calculator/Tax calculator are never disabled by the banner', () {
      // The banner is purely additive: none of these screens gate their
      // TextField/FilledButton/calculator call behind the entitlement
      // check — only the discovery card itself is conditional.
      expect(aiScreenSource.contains('enabled: !isSending'), isTrue);
      expect(affordabilitySource.contains('AffordabilityCalculator.calculate('), isTrue);
      expect(taxPlannerSource.contains('TaxCalculator.calculate') || taxPlannerSource.contains('taxProvider'), isTrue);
    });
  });

  group('Dashboard wiring (PHASE 5/12)', () {
    late String dashboardSource;

    setUpAll(() async {
      dashboardSource = await File('lib/features/dashboard/dashboard_screen.dart').readAsString();
    });

    test('the getting-started checklist is a pure addition — gated, never unconditional', () {
      expect(dashboardSource.contains('_GettingStartedChecklist'), isTrue);
      expect(dashboardSource.contains('if (!(wallets.isNotEmpty &&'), isTrue);
    });

    test('no existing Dashboard section was removed — all prior entry lines are still present', () {
      for (final marker in [
        '_FinancialActionsSection',
        '_FinancialTrendEntryLine',
        '_ProactiveInsightsSection',
        '_FinancialTimelineEntryLine',
        '_FinancialCompareEntryLine',
      ]) {
        expect(dashboardSource.contains(marker), isTrue, reason: '$marker missing — an existing section may have been removed');
      }
    });
  });

  group('13/16. Returning user — first-launch/onboarding wiring', () {
    late String profileSetupSource;
    late String ahaMomentSource;

    setUpAll(() async {
      profileSetupSource = await File('lib/features/profile/presentation/profile_setup_screen.dart').readAsString();
      ahaMomentSource = await File('lib/features/onboarding/presentation/aha_moment_screen.dart').readAsString();
    });

    test('completeFirstLaunch is called from AhaMomentScreen, not from ProfileSetupScreen', () {
      expect(profileSetupSource.contains('.notifier).completeFirstLaunch()'), isFalse);
      expect(ahaMomentSource.contains('.notifier).completeFirstLaunch()'), isTrue);
    });

    test('ProfileSetupScreen routes a still-onboarding user into the new sequence via the real route constant', () {
      expect(profileSetupSource.contains('AppRoutes.onboardingGoals'), isTrue);
      expect(profileSetupSource.contains("'/onboarding-goals'"), isFalse);
    });
  });
}
