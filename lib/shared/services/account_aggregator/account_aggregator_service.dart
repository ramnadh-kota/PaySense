import 'account_aggregator_models.dart';
import 'account_aggregator_provider_interface.dart';

/// ACCOUNT AGGREGATOR / ONE-TAP CONNECT — PHASE 1. The single seam the
/// rest of PaySense (future Riverpod providers, UI, ingestion adapter)
/// should depend on — never directly on an `AccountAggregatorProvider`
/// implementation. This class owns exactly one concrete provider
/// instance at a time, injected at construction, so switching from the
/// PHASE 3 mock to a real AA/TSP later (PHASE 17) never requires touching
/// any caller of this service.
///
/// SCOPE OF THIS PASS: this is intentionally a thin pass-through with NO
/// business logic yet. It does not:
///   - validate or enforce state-machine transitions (PHASE 4, future
///     work — e.g. rejecting a `syncFinancialData` call for a connection
///     that was never granted consent)
///   - persist [AccountAggregatorConnection]s anywhere (PHASE 4/6, future
///     work — no Hive box, no repository exists yet)
///   - convert [AccountAggregatorSyncResult] into
///     `TransactionIngestionRecord`s (PHASE 5, future work — that's a
///     separate AA adapter, not this service)
///   - map accounts onto PaySense wallets (PHASE 6, future work)
/// Every method here simply forwards to the injected provider, 1:1,
/// exactly as declared in [AccountAggregatorProvider]. Building the
/// safety/state logic on top of an unverified interface would risk
/// baking in the wrong shape before the interface has ever been
/// exercised — that logic belongs in the next phase, once this
/// abstraction itself has been reviewed.
class AccountAggregatorService {
  const AccountAggregatorService(this._provider);

  final AccountAggregatorProvider _provider;

  /// The identifier of the currently-active provider implementation
  /// (e.g. `"mock"`) — exposed so callers/tests can assert which provider
  /// is wired in without reaching into private state.
  String get activeProviderId => _provider.providerId;

  Future<AccountAggregatorConnection> createConsent({
    required String userId,
    required List<FinancialInstitutionType> institutionTypes,
    required Duration historyDuration,
  }) {
    return _provider.createConsent(
      userId: userId,
      institutionTypes: institutionTypes,
      historyDuration: historyDuration,
    );
  }

  Future<AccountAggregatorConnection> getConsentStatus({required String connectionId}) {
    return _provider.getConsentStatus(connectionId: connectionId);
  }

  Future<List<AccountAggregatorAccount>> fetchAccounts({required String connectionId}) {
    return _provider.fetchAccounts(connectionId: connectionId);
  }

  Future<AccountAggregatorSyncResult> syncFinancialData({
    required String connectionId,
    DateTime? since,
  }) {
    return _provider.syncFinancialData(connectionId: connectionId, since: since);
  }

  Future<AccountAggregatorConnection> revokeConsent({required String connectionId}) {
    return _provider.revokeConsent(connectionId: connectionId);
  }
}
