import 'account_aggregator_config.dart';
import 'account_aggregator_models.dart';
import 'account_aggregator_provider_interface.dart';
import 'mock_account_aggregator_provider.dart';

/// ACCOUNT AGGREGATOR — PRODUCTION HARDENING (Phase A3). Distinct from
/// [MockAccountAggregatorProvider] (Phase 3, pure dev/UI-testing data)
/// in PURPOSE, not in underlying data: no official AA/TSP sandbox API
/// specification exists in this repository, and per this milestone's
/// explicit "do not fabricate" rule, none is invented here. Instead,
/// this class demonstrates the EXACT integration shape a real sandbox
/// provider would need — configuration validation, simulated network
/// latency, and a `providerId` that's distinguishable from `mock` in
/// logs/telemetry — while its actual data comes from the SAME
/// deterministic generator [MockAccountAggregatorProvider] already
/// uses (composition, not duplication).
///
/// TODO(real-sandbox-integration): once a regulated AA/TSP's official
/// sandbox API/SDK is available, replace the delegation below with real
/// calls through `AccountAggregatorNetworkClient` — the request/response
/// shape (`AccountAggregatorConnection`/`AccountAggregatorAccount`/
/// `AccountAggregatorSyncResult`) should not need to change, since it was
/// designed provider-independent from Phase 1.
class SandboxAccountAggregatorProvider implements AccountAggregatorProvider, AccountAggregatorDevControls {
  SandboxAccountAggregatorProvider({required this.config, DateTime? referenceDate})
      : _delegate = MockAccountAggregatorProvider(referenceDate: referenceDate);

  final AccountAggregatorConfig config;
  final MockAccountAggregatorProvider _delegate;

  @override
  String get providerId => 'sandbox';

  @override
  String get displayName => config.providerName != null ? '${config.providerName} (Sandbox)' : 'Sandbox Provider';

  void _requireConfigured() {
    if (!config.isNetworkConfigured) {
      throw const AccountAggregatorException(
        AccountAggregatorErrorCode.configurationMissing,
        'Sandbox environment selected but AA_BASE_URL/AA_CLIENT_ID were not provided. '
        'See AccountAggregatorConfig.fromEnvironment().',
      );
    }
  }

  /// Stands in for real network latency so UI/loading-state code is
  /// exercised the same way it will be against a real sandbox.
  Future<void> _simulateNetworkLatency() => Future<void>.delayed(const Duration(milliseconds: 300));

  @override
  Future<AccountAggregatorConnection> createConsent({
    required String userId,
    required List<FinancialInstitutionType> institutionTypes,
    required Duration historyDuration,
  }) async {
    _requireConfigured();
    await _simulateNetworkLatency();
    // TODO(real-sandbox-integration): POST /aa/consent/initiate via
    // AccountAggregatorNetworkClient, mapping the JSON response into
    // AccountAggregatorConnection.
    final connection = await _delegate.createConsent(
      userId: userId,
      institutionTypes: institutionTypes,
      historyDuration: historyDuration,
    );
    return _rebrand(connection);
  }

  @override
  Future<AccountAggregatorConnection> getConsentStatus({required String connectionId}) async {
    _requireConfigured();
    await _simulateNetworkLatency();
    // TODO(real-sandbox-integration): GET /aa/consent/{id}.
    return _rebrand(await _delegate.getConsentStatus(connectionId: connectionId));
  }

  @override
  Future<List<AccountAggregatorAccount>> fetchAccounts({required String connectionId}) async {
    _requireConfigured();
    await _simulateNetworkLatency();
    // TODO(real-sandbox-integration): GET /aa/accounts.
    return _delegate.fetchAccounts(connectionId: connectionId);
  }

  @override
  Future<AccountAggregatorSyncResult> syncFinancialData({required String connectionId, DateTime? since}) async {
    _requireConfigured();
    await _simulateNetworkLatency();
    // TODO(real-sandbox-integration): GET /aa/transactions (+ balances).
    return _delegate.syncFinancialData(connectionId: connectionId, since: since);
  }

  @override
  Future<AccountAggregatorConnection> revokeConsent({required String connectionId}) async {
    _requireConfigured();
    await _simulateNetworkLatency();
    // TODO(real-sandbox-integration): POST /aa/revoke.
    return _rebrand(await _delegate.revokeConsent(connectionId: connectionId));
  }

  /// Test/dev-only, exactly like the underlying mock's own — a real
  /// sandbox's consent approval happens on the AA/TSP's own external
  /// page, which this offline sandbox has no way to simulate visually,
  /// so the same "simulate" controls remain available.
  @override
  AccountAggregatorConnection approveConsent(String connectionId) => _rebrand(_delegate.approveConsent(connectionId));
  @override
  AccountAggregatorConnection rejectConsent(String connectionId) => _rebrand(_delegate.rejectConsent(connectionId));
  @override
  AccountAggregatorConnection expireConsent(String connectionId) => _rebrand(_delegate.expireConsent(connectionId));

  AccountAggregatorConnection _rebrand(AccountAggregatorConnection connection) {
    return AccountAggregatorConnection(
      connectionId: connection.connectionId,
      providerId: providerId,
      providerName: displayName,
      status: connection.status,
      consentStatus: connection.consentStatus,
      createdAt: connection.createdAt,
      updatedAt: connection.updatedAt,
      lastSyncedAt: connection.lastSyncedAt,
      accounts: connection.accounts,
      errorMessage: connection.errorMessage,
    );
  }
}
