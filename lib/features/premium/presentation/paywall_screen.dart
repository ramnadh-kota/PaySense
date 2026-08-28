import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/shared/config/pricing_config.dart';
import 'package:paysense/shared/models/entitlement.dart';
import 'package:paysense/shared/providers/billing_provider.dart';
import 'package:paysense/shared/providers/entitlement_provider.dart';
import 'package:paysense/shared/services/analytics_service.dart';
import 'package:paysense/shared/widgets/app_card.dart';

/// The 6 strongest, most concrete benefits — never the raw
/// [EntitlementService.plusOnlyEntitlements] set dumped verbatim (some of
/// those, like [Entitlement.financialTimeline]/[Entitlement.comparePeriods],
/// are real but less headline-worthy than these).
const List<Entitlement> _headlineBenefits = [
  Entitlement.aiAssistant,
  Entitlement.financialPlanning,
  Entitlement.whatIf,
  Entitlement.advancedInsights,
  Entitlement.taxPlanner,
  Entitlement.proactiveAlerts,
];

/// CONSUMER MONETIZATION FOUNDATION (PHASE 8/9). No payment provider is
/// connected (see `EntitlementRepository`'s class doc) — the CTA here is
/// explicitly labeled as a development/preview switch, never implying a
/// real purchase completed.
class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  String _selectedPlanId = PricingConfig.defaultPlan.id;
  bool _isPurchasing = false;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.log(AnalyticsEvent.paywallViewed);
  }

  /// The real (non-dev-preview) purchase path — routes through
  /// [BillingService] rather than granting anything directly. Today this
  /// always resolves to [PurchaseStatus.productsUnavailable] (see
  /// [StubBillingService]'s doc) since no payment SDK is installed, but
  /// the flow itself — initiate, await the store's result, surface it,
  /// never touch entitlement here — is the same shape a real integration
  /// will use once `verifyAndGrantEntitlement` has a backend to call.
  Future<void> _startRealPurchase(PricingPlan plan) async {
    setState(() => _isPurchasing = true);
    AnalyticsService.instance.log(AnalyticsEvent.subscriptionStarted, metadata: {'planId': plan.id, 'devPreview': false});
    final result = await ref.read(billingServiceProvider).purchase(plan.id);
    if (!mounted) return;
    setState(() => _isPurchasing = false);
    if (result.message != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message!)));
    }
    // Deliberately no entitlement change here regardless of `result.status`
    // — see BillingService's class doc for why that's a separate,
    // server-verified step that doesn't exist yet.
  }

  @override
  Widget build(BuildContext context) {
    final tier = ref.watch(planTierProvider).value ?? PlanTier.free;
    final isFoundingUser = ref.watch(isFoundingUserProvider).value ?? false;
    final selectedPlan = PricingConfig.planById(_selectedPlanId) ?? PricingConfig.defaultPlan;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                children: [
                  if (isFoundingUser) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.workspace_premium_rounded, size: 16, color: AppColors.warning),
                          const SizedBox(width: 6),
                          Text(
                            PricingConfig.foundingBadgeLabel,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.warning,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Text(
                    'Your money deserves more than a tracker.',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'PaySense Plus turns your financial data into decisions.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 24),
                  AppCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        for (final entitlement in _headlineBenefits) ...[
                          Row(
                            children: [
                              Icon(Icons.check_circle_rounded, size: 18, color: AppColors.success),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  entitlement.label,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (entitlement != _headlineBenefits.last) const SizedBox(height: 12),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: PricingConfig.plans
                        .map(
                          (plan) => Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(right: plan == PricingConfig.plans.last ? 0 : 10),
                              child: _PlanCard(
                                plan: plan,
                                selected: plan.id == _selectedPlanId,
                                foundingPrice: isFoundingUser ? PricingConfig.foundingPrice(plan) : null,
                                onTap: () {
                                  setState(() => _selectedPlanId = plan.id);
                                  AnalyticsService.instance.log(
                                    AnalyticsEvent.pricingSelected,
                                    metadata: {'planId': plan.id},
                                  );
                                },
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Payments are not live yet in this beta. Nothing will be charged.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  // PLAY STORE / PRODUCTION HARDENING (PHASE O/P/14): the
                  // dev-preview branch below grants Plus with ZERO real
                  // payment verification — `kReleaseMode` is a compile-time
                  // constant, so that branch (and the direct
                  // `setTier(PlanTier.plus)` call inside it) is tree-shaken
                  // out of a real `flutter build apk/appbundle --release`
                  // entirely, not just hidden at runtime. A release build
                  // must NEVER expose a free unlock. The release path below
                  // instead routes through `BillingService.purchase`, which
                  // NEVER grants an entitlement itself — entitlement must
                  // stay server-authoritative (purchase token -> backend
                  // verification -> Play Developer API -> verified
                  // entitlement, see `BillingService.verifyAndGrantEntitlement`),
                  // which does not exist yet (no billing SDK is installed).
                  onPressed: tier == PlanTier.plus || _isPurchasing
                      ? null
                      : kReleaseMode
                          ? () => _startRealPurchase(selectedPlan)
                          : () async {
                              // DEVELOPMENT-SAFE PREVIEW ONLY — never simulates a
                              // real purchase. See EntitlementRepository's doc.
                              AnalyticsService.instance.log(
                                AnalyticsEvent.subscriptionStarted,
                                metadata: {'planId': selectedPlan.id, 'devPreview': true},
                              );
                              await ref.read(planTierProvider.notifier).setTier(PlanTier.plus);
                            },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isPurchasing
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          tier == PlanTier.plus
                              ? 'You have PaySense Plus'
                              : kReleaseMode
                                  ? 'Get PaySense Plus'
                                  : 'Preview PaySense Plus (Dev Mode)',
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.selected,
    required this.foundingPrice,
    required this.onTap,
  });

  final PricingPlan plan;
  final bool selected;
  final double? foundingPrice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.10) : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? AppColors.primary : AppColors.divider, width: selected ? 1.5 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (plan.badge != null)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppColors.lightTeal, borderRadius: BorderRadius.circular(999)),
                child: Text(
                  plan.badge!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
              ),
            Text(plan.label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            if (foundingPrice != null) ...[
              Text(
                plan.formattedPrice,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
              Text(
                '${plan.currencySymbol}${foundingPrice!.toStringAsFixed(0)}${plan.billingPeriodLabel}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: AppColors.primary),
              ),
            ] else
              Text(
                plan.formattedPrice,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
          ],
        ),
      ),
    );
  }
}
