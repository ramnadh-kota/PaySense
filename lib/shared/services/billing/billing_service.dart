import '../../config/pricing_config.dart';
import 'billing_models.dart';

/// GOOGLE PLAY BILLING PREPARATION (PHASE 14). The abstraction the rest
/// of the app depends on — never a concrete SDK type — so wiring in a
/// real `in_app_purchase`/Play Billing integration later means swapping
/// the implementation bound in `billingServiceProvider`, not rewriting
/// call sites.
///
/// CRITICAL INVARIANT (re-stated from [PurchaseResult]'s doc): a
/// [PurchaseStatus.purchased] result from [purchase]/[restorePurchases]
/// must NEVER, by itself, cause an entitlement to be granted anywhere in
/// this app. The only path to granting Plus from a real purchase is:
/// purchase() -> verifyAndGrantEntitlement(token) -> (server verifies) ->
/// entitlement granted. Nothing in this interface short-circuits that,
/// and no caller should either.
abstract class BillingService {
  /// Loads the products backing [PricingConfig.plans]' ids. Returns an
  /// empty list (never throws) when billing isn't available in this
  /// build — callers should treat an empty list the same as a
  /// [PurchaseStatus.productsUnavailable] purchase outcome.
  Future<List<BillingProduct>> loadProducts();

  /// Initiates a purchase for [productId]. In a real integration this
  /// resolves once the Play purchase sheet itself completes, is
  /// dismissed, or fails — a UI-blocking operation, not a background one.
  Future<PurchaseResult> purchase(String productId);

  /// Re-queries the store for the user's existing purchases (e.g. after
  /// a reinstall). Same invariant as [purchase] — a restored purchase
  /// still has to go through [verifyAndGrantEntitlement] before it can
  /// grant anything.
  Future<List<PurchaseResult>> restorePurchases();

  /// The ONLY path that may grant a Plus entitlement from a real
  /// purchase. Sends [purchaseToken] to PaySense's backend, which is
  /// responsible for calling the Google Play Developer API to confirm
  /// the purchase is genuine and not already refunded/consumed, before
  /// this returns true. Implementations must return false — never grant
  /// — whenever that backend doesn't exist or can't be reached.
  Future<bool> verifyAndGrantEntitlement(String purchaseToken);
}

/// PRODUCTION-SAFE STUB. No `in_app_purchase` package is installed in
/// this app and no Play Console product configuration exists yet (see
/// the PHASE 15 Play Store compliance audit) — this implementation stays
/// honest about that at every step rather than simulating success:
///
/// - [loadProducts] mirrors [PricingConfig.plans] for display purposes
///   only (the paywall already renders these prices independently of
///   billing) — it does NOT mean a purchase can actually be completed.
/// - [purchase] always resolves to [PurchaseStatus.productsUnavailable].
/// - [verifyAndGrantEntitlement] ALWAYS returns false — there is no
///   deployed backend to verify a purchase token against yet (would
///   require: a verification endpoint, Google Play Developer API
///   credentials, RTDN/Pub/Sub wiring for revocation/refund events).
///   This method is the exact seam that real backend integration
///   replaces — everything upstream of it (product display, purchase
///   initiation, the state machine) is already production-shaped.
class StubBillingService implements BillingService {
  const StubBillingService();

  @override
  Future<List<BillingProduct>> loadProducts() async {
    return PricingConfig.plans
        .map(
          (plan) => BillingProduct(
            productId: plan.id,
            title: plan.label,
            formattedPrice: plan.formattedPrice,
            billingPeriodLabel: plan.billingPeriodLabel,
          ),
        )
        .toList();
  }

  @override
  Future<PurchaseResult> purchase(String productId) async {
    return PurchaseResult(
      status: PurchaseStatus.productsUnavailable,
      productId: productId,
      message: 'Real purchases aren\'t live yet — PaySense Plus billing is still being set up. Nothing was charged.',
    );
  }

  @override
  Future<List<PurchaseResult>> restorePurchases() async => const [];

  @override
  Future<bool> verifyAndGrantEntitlement(String purchaseToken) async => false;
}
