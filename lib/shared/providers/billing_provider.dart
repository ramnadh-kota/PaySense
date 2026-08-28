import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/billing/billing_service.dart';

/// GOOGLE PLAY BILLING PREPARATION (PHASE 14). Bound to [StubBillingService]
/// today — swapping in a real Play Billing-backed implementation once one
/// exists is a one-line change here, not a rewrite of any screen that
/// depends on [BillingService].
final billingServiceProvider = Provider<BillingService>((ref) => const StubBillingService());
