import 'account_aggregator_config.dart';
import 'account_aggregator_models.dart';
import 'account_aggregator_network_client.dart';
import 'account_aggregator_provider_interface.dart';

/// ACCOUNT AGGREGATOR — PRODUCTION HARDENING (Phase A2/A4). The
/// placeholder for a REAL, regulated AA/TSP integration. Every method
/// throws [AccountAggregatorErrorCode.notImplemented] — this class exists
/// so [AccountAggregatorEnvironment.production] has a concrete,
/// SELECTABLE implementation that fails loudly and honestly rather than
/// the provider-selection layer silently substituting the mock (see
/// `account_aggregator_provider.dart`'s explicit rule: "production must
/// never silently fall back to mock").
///
/// TO ACTIVATE A REAL PROVIDER: once a regulated AA/TSP is selected and
/// PaySense's own backend boundary (PHASE B) is deployed, implement each
/// method below using [AccountAggregatorNetworkClient] to call this
/// app's OWN backend endpoints (`/aa/consent/initiate`, `/aa/consent/{id}`,
/// `/aa/accounts`, `/aa/transactions`, `/aa/revoke` — see the backend
/// boundary's own documentation) — never the AA/TSP's endpoints directly
/// from the Flutter app. No code above this class (UI, ingestion,
/// wallet mapping) should need to change.
class ProductionAccountAggregatorProvider implements AccountAggregatorProvider {
  ProductionAccountAggregatorProvider({required this.config}) : networkClient = AccountAggregatorNetworkClient(config: config);

  final AccountAggregatorConfig config;

  /// Exposed so a future real implementation can use it directly —
  /// unused by any method below today, since every method short-circuits
  /// with [_notImplemented] before ever needing it.
  final AccountAggregatorNetworkClient networkClient;

  @override
  String get providerId => 'production';

  @override
  String get displayName => config.providerName ?? 'Production Account Aggregator';

  Never _notImplemented(String method) {
    throw AccountAggregatorException(
      AccountAggregatorErrorCode.notImplemented,
      'Real Account Aggregator integration ($method) is not yet configured. '
      'A regulated AA/TSP provider, FIU registration, and backend deployment '
      'are required before this can connect to a real bank.',
    );
  }

  @override
  Future<AccountAggregatorConnection> createConsent({
    required String userId,
    required List<FinancialInstitutionType> institutionTypes,
    required Duration historyDuration,
  }) async =>
      _notImplemented('createConsent');

  @override
  Future<AccountAggregatorConnection> getConsentStatus({required String connectionId}) async =>
      _notImplemented('getConsentStatus');

  @override
  Future<List<AccountAggregatorAccount>> fetchAccounts({required String connectionId}) async =>
      _notImplemented('fetchAccounts');

  @override
  Future<AccountAggregatorSyncResult> syncFinancialData({required String connectionId, DateTime? since}) async =>
      _notImplemented('syncFinancialData');

  @override
  Future<AccountAggregatorConnection> revokeConsent({required String connectionId}) async =>
      _notImplemented('revokeConsent');
}
