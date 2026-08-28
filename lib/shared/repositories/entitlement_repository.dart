import 'package:hive/hive.dart';

import '../models/entitlement.dart';

/// CONSUMER MONETIZATION FOUNDATION — PHASE 4/9. Deliberately its OWN
/// repository (not folded into [AppSettingsRepository], which is about UI
/// preferences) so a real payment provider (Google Play Billing,
/// RevenueCat, etc.) can replace this file's internals later without any
/// other file in the app needing to change — every call site only ever
/// talks to `EntitlementRepository`/`entitlementServiceProvider`, never to
/// Hive directly.
///
/// Reuses the SAME already-open, untyped `'app_settings'` Hive box (no new
/// box/migration needed) under a clearly namespaced key prefix.
///
/// This is a DEVELOPMENT-SAFE MOCK: [PlanTier] is stored locally and can be
/// changed instantly for testing/preview. It never claims a real purchase
/// occurred, never creates a transaction, and is not wired to any payment
/// SDK (none is installed in this app yet).
class EntitlementRepository {
  EntitlementRepository._();

  static final EntitlementRepository instance = EntitlementRepository._();

  static const String _boxName = 'app_settings';
  static const String _planTierKey = 'billing.planTier';
  static const String _isFoundingUserKey = 'billing.isFoundingUser';

  Box get _box => Hive.box(_boxName);

  Future<PlanTier> getPlanTier() async {
    final raw = _box.get(_planTierKey) as String?;
    return raw == PlanTier.plus.name ? PlanTier.plus : PlanTier.free;
  }

  /// Sets the LOCAL mock plan tier. This is a development/preview switch
  /// only — see the class doc. It never simulates a payment.
  Future<void> setPlanTier(PlanTier tier) async {
    await _box.put(_planTierKey, tier.name);
  }

  /// Whether this install is flagged as a "Founding Member" for the beta
  /// founding-offer UI (PHASE 9). Off by default.
  Future<bool> isFoundingUser() async {
    return (_box.get(_isFoundingUserKey) as bool?) ?? false;
  }

  Future<void> setFoundingUser(bool value) async {
    await _box.put(_isFoundingUserKey, value);
  }
}
