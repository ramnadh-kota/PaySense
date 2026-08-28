// Pure tests for EntitlementService (Consumer Monetization Foundation,
// PHASE 4/16 items 7-9).
import 'package:flutter_test/flutter_test.dart';
import 'package:paysense/shared/models/entitlement.dart';

void main() {
  group('7. Free entitlement access', () {
    test('free tier includes the core money-tracking loop', () {
      for (final e in [
        Entitlement.basicDashboard,
        Entitlement.transactions,
        Entitlement.wallets,
        Entitlement.budgets,
        Entitlement.goals,
        Entitlement.reports,
        Entitlement.financialHealth,
      ]) {
        expect(EntitlementService.isIncludedInTier(PlanTier.free, e), isTrue, reason: '$e should be free');
      }
    });

    test('free tier includes a first taste of intelligence (insights, affordability)', () {
      expect(EntitlementService.isIncludedInTier(PlanTier.free, Entitlement.financialInsights), isTrue);
      expect(EntitlementService.isIncludedInTier(PlanTier.free, Entitlement.affordability), isTrue);
    });

    test('free tier excludes every Plus-only capability', () {
      for (final e in [
        Entitlement.financialPlanning,
        Entitlement.financialTimeline,
        Entitlement.comparePeriods,
        Entitlement.aiAssistant,
        Entitlement.whatIf,
        Entitlement.taxPlanner,
        Entitlement.advancedInsights,
        Entitlement.proactiveAlerts,
      ]) {
        expect(EntitlementService.isIncludedInTier(PlanTier.free, e), isFalse, reason: '$e should NOT be free');
      }
    });
  });

  group('8. Plus entitlement access', () {
    test('plus tier includes every single entitlement, with no exceptions', () {
      for (final e in Entitlement.values) {
        expect(EntitlementService.isIncludedInTier(PlanTier.plus, e), isTrue, reason: '$e should be included in plus');
      }
    });
  });

  group('9. Premium gating — the single source of truth', () {
    test('plusOnlyEntitlements is exactly the complement of the free set', () {
      final plusOnly = EntitlementService.plusOnlyEntitlements;
      for (final e in Entitlement.values) {
        final isFree = EntitlementService.isIncludedInTier(PlanTier.free, e);
        expect(plusOnly.contains(e), !isFree);
      }
    });

    test('every Entitlement value is classified as either free or plus-only — none unhandled', () {
      final plusOnly = EntitlementService.plusOnlyEntitlements;
      for (final e in Entitlement.values) {
        final isFree = EntitlementService.isIncludedInTier(PlanTier.free, e);
        expect(isFree || plusOnly.contains(e), isTrue);
      }
    });

    test('every entitlement has a non-empty human-readable label', () {
      for (final e in Entitlement.values) {
        expect(e.label, isNotEmpty);
      }
    });
  });
}
