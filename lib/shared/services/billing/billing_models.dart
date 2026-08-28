import 'package:flutter/foundation.dart';

/// GOOGLE PLAY BILLING PREPARATION (PHASE 14). The lifecycle a real
/// purchase attempt moves through. Mirrors the Account Aggregator's own
/// `ConnectionStatus`/`ConsentStatus` pattern — an explicit state machine
/// rather than a bare success/failure boolean, so the UI can render every
/// intermediate state honestly instead of collapsing them into a spinner.
enum PurchaseStatus {
  idle,
  pending,
  purchased,
  restored,
  canceled,
  failed,
  productsUnavailable,
  verificationRequired,
}

/// A store-reported (or, until a real SDK is wired in, locally-mirrored)
/// purchasable product — display data only, never carries entitlement
/// logic itself.
@immutable
class BillingProduct {
  const BillingProduct({
    required this.productId,
    required this.title,
    required this.formattedPrice,
    required this.billingPeriodLabel,
  });

  /// The Play Billing product id this maps to once one is configured in
  /// Play Console — today this is the same id as [PricingPlan.id].
  final String productId;
  final String title;
  final String formattedPrice;
  final String billingPeriodLabel;
}

/// The outcome of one purchase (or restore) attempt.
///
/// CRITICAL INVARIANT: [status] being [PurchaseStatus.purchased] means
/// the store itself reported success — it does NOT mean an entitlement
/// should be granted. See [BillingService.verifyAndGrantEntitlement]'s
/// doc for why those two steps are deliberately kept separate.
@immutable
class PurchaseResult {
  const PurchaseResult({required this.status, this.purchaseToken, this.productId, this.message});

  final PurchaseStatus status;

  /// Opaque token a real Play Billing purchase would carry, to be sent to
  /// PaySense's backend for server-side verification via the Google Play
  /// Developer API. Always null from [StubBillingService] — there is no
  /// SDK to produce one yet.
  final String? purchaseToken;
  final String? productId;

  /// Human-readable reason, safe to show directly to the user for
  /// failed/unavailable/canceled/pending states.
  final String? message;
}
