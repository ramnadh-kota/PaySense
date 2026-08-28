import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/entitlement.dart';
import '../repositories/entitlement_repository.dart';

final entitlementRepositoryProvider = Provider<EntitlementRepository>((ref) {
  return EntitlementRepository.instance;
});

/// The user's current plan — a plain [AsyncNotifierProvider] so every
/// screen that watches it rebuilds the instant the (mock) tier changes.
final planTierProvider = AsyncNotifierProvider<PlanTierNotifier, PlanTier>(PlanTierNotifier.new);

class PlanTierNotifier extends AsyncNotifier<PlanTier> {
  @override
  Future<PlanTier> build() async {
    return ref.watch(entitlementRepositoryProvider).getPlanTier();
  }

  /// Development/preview switch only — see [EntitlementRepository]'s class
  /// doc. Never simulates a real purchase.
  Future<void> setTier(PlanTier tier) async {
    final repo = ref.read(entitlementRepositoryProvider);
    await repo.setPlanTier(tier);
    state = AsyncValue.data(tier);
  }
}

final isFoundingUserProvider = AsyncNotifierProvider<IsFoundingUserNotifier, bool>(IsFoundingUserNotifier.new);

class IsFoundingUserNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    return ref.watch(entitlementRepositoryProvider).isFoundingUser();
  }

  Future<void> setFoundingUser(bool value) async {
    final repo = ref.read(entitlementRepositoryProvider);
    await repo.setFoundingUser(value);
    state = AsyncValue.data(value);
  }
}

/// THE single entry point every feature should use to ask "can the current
/// user access X" — never a bespoke `if (tier == ...)` inside a feature.
/// Defaults to [PlanTier.free] (the safe default) while the tier is still
/// loading. Pure logic lives in [EntitlementService.isIncludedInTier]; this
/// is only the Riverpod-aware wrapper around it.
bool canAccessEntitlement(WidgetRef ref, Entitlement entitlement) {
  final tier = ref.watch(planTierProvider).value ?? PlanTier.free;
  return EntitlementService.isIncludedInTier(tier, entitlement);
}
