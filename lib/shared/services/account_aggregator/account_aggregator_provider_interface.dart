import 'account_aggregator_models.dart';

/// ACCOUNT AGGREGATOR / ONE-TAP CONNECT — PHASE 2. The single
/// vendor-independent contract every AA/TSP integration must implement.
///
/// `AccountAggregatorService` (and everything above it — UI, ingestion)
/// depends ONLY on this interface, never on a concrete implementation.
/// This is what prevents vendor lock-in: swapping the sandbox
/// `MockAccountAggregatorProvider` (PHASE 3, not built in this pass) for
/// a real, regulated AA/TSP provider later is a one-file change — nothing
/// above this boundary needs to know or care.
///
/// FILE NAMING NOTE: this is deliberately NOT named
/// `account_aggregator_provider.dart` even though the class is named
/// `AccountAggregatorProvider` (matching the spec exactly) — in this
/// codebase every `*_provider.dart` file is a Riverpod state provider
/// (`wallet_provider.dart`, `csv_import_provider.dart`, etc.). Naming
/// this file that way would mislead anyone searching by convention.
///
/// PHASE 17 (future work, not built in this pass) — REAL PROVIDER
/// BOUNDARY: when a real, approved AA/TSP is selected, a new
/// implementation of this interface (e.g. `FinvuAccountAggregatorProvider`)
/// gets added alongside `MockAccountAggregatorProvider`. That
/// implementation is exactly where the following would need to be
/// configured — NONE of it exists yet and none of it is fabricated here:
///   - the regulated AA/TSP's actual SDK or REST API base URL
///   - API keys / client credentials issued by that provider (never
///     hardcoded — must come from secure runtime configuration)
///   - the FIU (Financial Information User) certificate/registration
///     PaySense would need from Sahamati to legally participate in the
///     AA ecosystem
///   - the encryption/decryption scheme mandated by the AA framework
///     (ECDH key exchange + AES-GCM per the ReBIT AA API spec) for
///     decrypting Financial Information payloads
///   - a backend component (PHASE 18, future work) to hold provider
///     secrets, since those must never ship inside the Flutter app
///     binary
/// Per this task's explicit stop condition, none of the above is
/// available today, so none of it is guessed or stubbed with fake
/// endpoints/credentials — only this interface and the mock
/// implementation are safe to build now.
abstract class AccountAggregatorProvider {
  /// Stable machine identifier for this implementation (e.g. `"mock"`,
  /// later `"finvu"`/`"onemoney"`) — stamped onto every
  /// [AccountAggregatorConnection.providerId] this provider creates.
  /// Never a display name; never used for anything user-facing.
  String get providerId;

  /// Human-readable name for display only (e.g. "Sandbox / Mock
  /// Provider"). Never used for logic — [providerId] is the only value
  /// that should ever be branched on.
  String get displayName;

  /// Starts a new consent request for the given [institutionTypes] and
  /// [historyDuration] (PHASE 9's "3/6/12 months" choice, default 6
  /// months per that phase — the CALLER is responsible for defaulting,
  /// this method just honors whatever duration it's given).
  ///
  /// [userId] is an opaque, PaySense-local identifier supplied by the
  /// caller (PaySense has no server-side account system — see PHASE 0
  /// audit — so this is NOT a backend user id; callers should pass a
  /// stable local identifier such as `UserProfile.id`).
  ///
  /// Returns a connection in [ConnectionStatus.awaitingConsent] (or
  /// [ConnectionStatus.failed] if the provider could not even start the
  /// flow) — NEVER [ConnectionStatus.connected] from this call alone.
  Future<AccountAggregatorConnection> createConsent({
    required String userId,
    required List<FinancialInstitutionType> institutionTypes,
    required Duration historyDuration,
  });

  /// Polls/refreshes the current state of a previously created consent.
  /// Implementations should update [AccountAggregatorConnection.status]/
  /// `.consentStatus` to reflect reality — this is the only method
  /// allowed to advance a connection out of `awaitingConsent`.
  Future<AccountAggregatorConnection> getConsentStatus({required String connectionId});

  /// Lists the financial accounts discovered under an approved consent.
  /// Must only be called (and only return non-empty) once
  /// `getConsentStatus` reports [ConsentStatus.approved] — an
  /// implementation may throw [AccountAggregatorException] with
  /// [AccountAggregatorErrorCode.invalidConnection] otherwise.
  Future<List<AccountAggregatorAccount>> fetchAccounts({required String connectionId});

  /// Fetches account balances + transactions for every account under
  /// [connectionId]. [since] restricts to transactions on/after that
  /// date (used for incremental re-syncs, PHASE 14's "Sync now", future
  /// work) — null means "the full history window granted by the
  /// consent".
  ///
  /// Returns raw [AccountAggregatorTransaction]s, deliberately NOT
  /// `TransactionIngestionRecord`s — see that class's doc comment for
  /// why. Must faithfully report [AccountAggregatorSyncResult.isPartial]
  /// rather than silently dropping accounts that failed to sync.
  Future<AccountAggregatorSyncResult> syncFinancialData({
    required String connectionId,
    DateTime? since,
  });

  /// Revokes consent for a connection. Must return the connection with
  /// [ConnectionStatus.revoked] / [ConsentStatus.revoked] on success.
  /// Per PHASE 15 (future work): revoking consent must NEVER delete
  /// already-ingested historical transactions — that is a concern for
  /// the caller (PaySense's own repositories), not this provider layer,
  /// which only ever reports upstream connection/consent state.
  Future<AccountAggregatorConnection> revokeConsent({required String connectionId});
}

/// ACCOUNT AGGREGATOR — PRODUCTION HARDENING. The "simulate the AA/TSP's
/// external consent page" controls — implemented by both
/// [MockAccountAggregatorProvider] and [SandboxAccountAggregatorProvider]
/// (never by a real production provider, which has no need for them: a
/// real user approves/rejects on the actual bank/AA page). Giving both
/// non-production providers a shared interface lets the UI layer
/// (`accountAggregatorDevControlsProvider`) offer the same "Simulate
/// Approve/Reject" affordance regardless of which of the two is active,
/// without the UI needing to know which concrete class it's talking to.
abstract class AccountAggregatorDevControls {
  AccountAggregatorConnection approveConsent(String connectionId);
  AccountAggregatorConnection rejectConsent(String connectionId);
  AccountAggregatorConnection expireConsent(String connectionId);
}
