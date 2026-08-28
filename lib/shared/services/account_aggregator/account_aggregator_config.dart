import 'package:flutter/foundation.dart';

/// ACCOUNT AGGREGATOR — PRODUCTION HARDENING (Phase A1). Which concrete
/// [AccountAggregatorProvider] implementation is active. `production`
/// NEVER silently falls back to `mock` — see
/// `account_aggregator_provider.dart`'s selection logic.
enum AccountAggregatorEnvironment { mock, sandbox, production }

/// Environment-driven AA configuration — every value is read from
/// `--dart-define` (or defaults safe for local development), NEVER
/// hardcoded. There is deliberately no field here for an API key/client
/// secret: per this milestone's explicit security rule, long-lived AA/TSP
/// secrets must live behind PaySense's own backend boundary (see
/// PHASE B, `ai_backend`'s sibling AA service), never inside the Flutter
/// binary. [clientId] is a PUBLIC identifier only (safe to ship in an
/// app binary, the same way an OAuth "client id" — not "client secret"
/// — is public).
@immutable
class AccountAggregatorConfig {
  const AccountAggregatorConfig({
    required this.environment,
    this.providerName,
    this.baseUrl,
    this.clientId,
    this.redirectUri,
    this.connectTimeout = const Duration(seconds: 15),
    this.maxRetries = 2,
  });

  final AccountAggregatorEnvironment environment;

  /// The regulated AA/TSP's stable name once one is selected (e.g.
  /// `"finvu"`) — null for mock/sandbox.
  final String? providerName;

  /// PaySense's OWN backend boundary URL for AA operations (see PHASE B)
  /// — the Flutter app talks to this, never directly to the AA/TSP.
  final String? baseUrl;
  final String? clientId;
  final String? redirectUri;
  final Duration connectTimeout;
  final int maxRetries;

  /// Reads configuration from compile-time `--dart-define` values, e.g.:
  /// `flutter run --dart-define=AA_ENVIRONMENT=sandbox --dart-define=AA_BASE_URL=https://...`
  ///
  /// Defaults to [AccountAggregatorEnvironment.mock] when nothing is
  /// defined — the safe default for local development so a developer is
  /// never accidentally pointed at a real backend.
  factory AccountAggregatorConfig.fromEnvironment() {
    const environmentName = String.fromEnvironment('AA_ENVIRONMENT', defaultValue: 'mock');
    final environment = AccountAggregatorEnvironment.values.firstWhere(
      (e) => e.name == environmentName,
      orElse: () => AccountAggregatorEnvironment.mock,
    );

    const baseUrl = String.fromEnvironment('AA_BASE_URL');
    const clientId = String.fromEnvironment('AA_CLIENT_ID');
    const redirectUri = String.fromEnvironment('AA_REDIRECT_URI');
    const providerName = String.fromEnvironment('AA_PROVIDER_NAME');
    const timeoutSeconds = int.fromEnvironment('AA_TIMEOUT_SECONDS', defaultValue: 15);
    const retries = int.fromEnvironment('AA_MAX_RETRIES', defaultValue: 2);

    return AccountAggregatorConfig(
      environment: environment,
      providerName: providerName.isEmpty ? null : providerName,
      baseUrl: baseUrl.isEmpty ? null : baseUrl,
      clientId: clientId.isEmpty ? null : clientId,
      redirectUri: redirectUri.isEmpty ? null : redirectUri,
      connectTimeout: Duration(seconds: timeoutSeconds),
      maxRetries: retries,
    );
  }

  /// True once enough configuration exists to even ATTEMPT a real
  /// (sandbox or production) network call — never true for `mock`, which
  /// needs no configuration at all.
  bool get isNetworkConfigured =>
      environment != AccountAggregatorEnvironment.mock && baseUrl != null && clientId != null;
}
