/// CONSUMER MONETIZATION FOUNDATION — PHASE 4. Pure Dart, zero Flutter/
/// Riverpod/Hive/network dependency. This is the SINGLE source of truth
/// for "what does each plan tier include" — no feature anywhere in the app
/// should decide this on its own. Deliberately named differently from the
/// existing, unrelated `SubscriptionCalculator`/`SubscriptionSummary`
/// (the recurring-transaction "Subscription Manager" feature) to avoid any
/// confusion between the two.
library;

/// The user's current billing plan. No payment provider is connected yet
/// (see [PricingConfig] / `PaywallScreen`) — this is deliberately isolated
/// so a real provider (Google Play Billing, RevenueCat, etc.) can be
/// plugged in later without touching any of the `canAccess` call sites.
enum PlanTier { free, plus }

/// Every gate-able capability in the app. Adding a new gated feature means
/// adding one value here and one line in [EntitlementService._freeEntitlements]
/// — never a bespoke check inside the feature itself.
enum Entitlement {
  basicDashboard,
  transactions,
  wallets,
  budgets,
  goals,
  reports,
  financialHealth,
  financialInsights,
  financialPlanning,
  financialTimeline,
  comparePeriods,
  affordability,
  aiAssistant,
  whatIf,
  taxPlanner,
  advancedInsights,
  proactiveAlerts,
}

/// Human-readable label for a premium discovery / paywall bullet — never
/// used to gate anything itself, purely presentational.
extension EntitlementLabel on Entitlement {
  String get label {
    switch (this) {
      case Entitlement.basicDashboard:
        return 'Dashboard';
      case Entitlement.transactions:
        return 'Transactions';
      case Entitlement.wallets:
        return 'Wallets';
      case Entitlement.budgets:
        return 'Budgets';
      case Entitlement.goals:
        return 'Goals';
      case Entitlement.reports:
        return 'Reports';
      case Entitlement.financialHealth:
        return 'Financial Health';
      case Entitlement.financialInsights:
        return 'Financial Insights';
      case Entitlement.financialPlanning:
        return 'Advanced Financial Planning';
      case Entitlement.financialTimeline:
        return 'Financial Timeline';
      case Entitlement.comparePeriods:
        return 'Compare Periods';
      case Entitlement.affordability:
        return 'Affordability Analysis';
      case Entitlement.aiAssistant:
        return 'AI Financial Assistant';
      case Entitlement.whatIf:
        return 'What-If Financial Simulations';
      case Entitlement.taxPlanner:
        return 'Tax Planning';
      case Entitlement.advancedInsights:
        return 'Personalized Financial Insights';
      case Entitlement.proactiveAlerts:
        return 'Proactive Alerts';
    }
  }
}

/// The centralized entitlement check. Every feature in the app that needs
/// to know "is this available on the user's plan" calls THIS — never a
/// bespoke `if (tier == ...)` of its own. Pure and stateless: it takes the
/// tier as an argument rather than reading it itself, so it has zero
/// Riverpod/Hive dependency and is trivially unit-testable. The
/// Riverpod-aware convenience wrapper lives in
/// `lib/shared/providers/entitlement_provider.dart` (`canAccessEntitlement`).
class EntitlementService {
  EntitlementService._();

  /// Free plan — deliberately genuinely useful on its own (PHASE 5): the
  /// core money-tracking loop (Dashboard/Wallets/Transactions/Budgets/
  /// Goals/Reports/Financial Health) plus a first taste of PaySense's
  /// intelligence (basic Financial Insights, basic Affordability) so a
  /// free user can already feel "this understands my money," not just
  /// "this stores my money."
  static const Set<Entitlement> _freeEntitlements = {
    Entitlement.basicDashboard,
    Entitlement.transactions,
    Entitlement.wallets,
    Entitlement.budgets,
    Entitlement.goals,
    Entitlement.reports,
    Entitlement.financialHealth,
    Entitlement.financialInsights,
    Entitlement.affordability,
  };

  /// True if [tier] includes [entitlement]. [PlanTier.plus] always
  /// includes everything free includes, plus everything else.
  static bool isIncludedInTier(PlanTier tier, Entitlement entitlement) {
    if (tier == PlanTier.plus) return true;
    return _freeEntitlements.contains(entitlement);
  }

  /// Every entitlement NOT included in [PlanTier.free] — the exact set
  /// [PaywallScreen] and every premium-discovery CTA should describe.
  static Set<Entitlement> get plusOnlyEntitlements =>
      Entitlement.values.where((e) => !_freeEntitlements.contains(e)).toSet();
}
