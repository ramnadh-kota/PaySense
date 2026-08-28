import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/account_aggregator/account_aggregator_config.dart';
import '../services/account_aggregator/account_aggregator_provider_interface.dart';
import '../services/account_aggregator/account_aggregator_service.dart';
import '../services/account_aggregator/mock_account_aggregator_provider.dart';
import '../services/account_aggregator/production_account_aggregator_provider.dart';
import '../services/account_aggregator/sandbox_account_aggregator_provider.dart';

/// ACCOUNT AGGREGATOR — dependency-injection wiring, following the same
/// `Provider<T>` convention already used by
/// `transactionRepositoryProvider`/`walletRepositoryProvider`.
final accountAggregatorConfigProvider = Provider<AccountAggregatorConfig>((ref) {
  return AccountAggregatorConfig.fromEnvironment();
});

/// PRODUCTION HARDENING (Phase A4) — the single provider-selection layer.
/// Reads [AccountAggregatorConfig.environment] and picks the matching
/// concrete implementation. `production` NEVER silently falls back to
/// `mock` — it always resolves to [ProductionAccountAggregatorProvider],
/// whose every method throws a clear, honest "not implemented yet" error
/// until a real provider is wired in, rather than quietly serving fake
/// data under a real-looking environment name.
final accountAggregatorProviderImplProvider = Provider<AccountAggregatorProvider>((ref) {
  final config = ref.watch(accountAggregatorConfigProvider);
  switch (config.environment) {
    case AccountAggregatorEnvironment.mock:
      return MockAccountAggregatorProvider();
    case AccountAggregatorEnvironment.sandbox:
      return SandboxAccountAggregatorProvider(config: config);
    case AccountAggregatorEnvironment.production:
      return ProductionAccountAggregatorProvider(config: config);
  }
});

/// The single seam the rest of PaySense should depend on for Account
/// Aggregator functionality — never on a concrete provider directly,
/// except in test/dev wiring such as this file.
final accountAggregatorServiceProvider = Provider<AccountAggregatorService>((ref) {
  return AccountAggregatorService(ref.watch(accountAggregatorProviderImplProvider));
});

/// Exposes the shared dev-controls surface ([AccountAggregatorDevControls])
/// ONLY when the active provider actually offers it (mock or sandbox) —
/// `null` whenever a real production provider is configured. This is the
/// ONE sanctioned place the AA connect UI is allowed to reach past the
/// [AccountAggregatorService] abstraction: to offer "Simulate
/// Approve/Reject" dev controls, which have no equivalent on the
/// production interface (a real consent approval happens on the AA/TSP's
/// own external flow, not inside PaySense). A screen watching this
/// provider and getting `null` should simply not render those controls
/// at all — no other code path should ever change when a real provider
/// replaces mock/sandbox.
final accountAggregatorDevControlsProvider = Provider<AccountAggregatorDevControls?>((ref) {
  final impl = ref.watch(accountAggregatorProviderImplProvider);
  return impl is AccountAggregatorDevControls ? impl as AccountAggregatorDevControls : null;
});
