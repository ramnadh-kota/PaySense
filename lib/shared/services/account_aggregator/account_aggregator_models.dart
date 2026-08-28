import 'package:flutter/foundation.dart';

/// ACCOUNT AGGREGATOR / ONE-TAP CONNECT — PHASE 1. Provider-independent
/// domain models for India's consent-based Account Aggregator (AA)
/// framework. Nothing here depends on Flutter widgets, Riverpod, Hive, or
/// any specific AA/TSP vendor (Finvu, OneMoney, etc.) — that independence
/// is the entire point (see `AccountAggregatorProvider`, PHASE 2).
///
/// PRIVACY: none of these models has a field for a password, PIN, OTP,
/// CVV, card number, or any other banking credential — PaySense never
/// collects those, by construction, not by convention.
///
/// NAMING NOTE: PaySense already has an unrelated `Account` model
/// (`lib/shared/models/account.dart`, Hive typeId 8) for the local
/// login/signup credential record. Everything in this file is
/// deliberately named `AccountAggregator...` to avoid any confusion with
/// that class — never introduce a bare `Account` type for a financial
/// account.

/// The lifecycle of one connection to a financial institution (or set of
/// institutions) via an AA provider. See PHASE 4 (future work — not built
/// in this pass) for the state-machine transition rules; this enum only
/// defines the vocabulary.
enum ConnectionStatus {
  disconnected,
  initializing,
  awaitingConsent,
  consentGranted,
  fetching,
  syncing,
  connected,
  partiallyConnected,
  failed,
  revoked,
}

extension ConnectionStatusLabel on ConnectionStatus {
  /// A short, human-readable label — never technical jargon, per PHASE 16
  /// (future work)'s "no stack traces, human language" rule.
  String get label {
    switch (this) {
      case ConnectionStatus.disconnected:
        return 'Not connected';
      case ConnectionStatus.initializing:
        return 'Starting connection…';
      case ConnectionStatus.awaitingConsent:
        return 'Waiting for your consent';
      case ConnectionStatus.consentGranted:
        return 'Consent granted';
      case ConnectionStatus.fetching:
        return 'Fetching accounts…';
      case ConnectionStatus.syncing:
        return 'Syncing transactions…';
      case ConnectionStatus.connected:
        return 'Connected';
      case ConnectionStatus.partiallyConnected:
        return 'Partially connected';
      case ConnectionStatus.failed:
        return 'Connection issue';
      case ConnectionStatus.revoked:
        return 'Access revoked';
    }
  }

  /// True only once the provider has CONFIRMED a successful connection —
  /// never set optimistically. See PHASE 4's explicit rule: "Never grant
  /// 'connected' before the provider confirms successful connection."
  bool get isConnected => this == ConnectionStatus.connected || this == ConnectionStatus.partiallyConnected;
}

/// The status of the user's consent artefact itself, as distinct from the
/// broader [ConnectionStatus] (a connection can be `awaitingConsent` while
/// the consent is `pending`, for example).
enum ConsentStatus { created, pending, approved, rejected, expired, revoked }

extension ConsentStatusLabel on ConsentStatus {
  String get label {
    switch (this) {
      case ConsentStatus.created:
        return 'Consent created';
      case ConsentStatus.pending:
        return 'Waiting for approval';
      case ConsentStatus.approved:
        return 'Approved';
      case ConsentStatus.rejected:
        return 'Rejected';
      case ConsentStatus.expired:
        return 'Expired';
      case ConsentStatus.revoked:
        return 'Revoked';
    }
  }
}

/// The category of financial institution/instrument an AA-linked account
/// represents — mirrors the FIP (Financial Information Provider) types
/// recognized by India's AA ecosystem, kept broad enough to cover
/// PaySense's existing Wallet/Loan concepts.
enum FinancialInstitutionType {
  bank,
  creditCard,
  deposit,
  loan,
  mutualFund,
  equity,
  insurance,
  pension,
  other,
}

extension FinancialInstitutionTypeLabel on FinancialInstitutionType {
  String get label {
    switch (this) {
      case FinancialInstitutionType.bank:
        return 'Bank Account';
      case FinancialInstitutionType.creditCard:
        return 'Credit Card';
      case FinancialInstitutionType.deposit:
        return 'Deposit';
      case FinancialInstitutionType.loan:
        return 'Loan';
      case FinancialInstitutionType.mutualFund:
        return 'Mutual Fund';
      case FinancialInstitutionType.equity:
        return 'Equity';
      case FinancialInstitutionType.insurance:
        return 'Insurance';
      case FinancialInstitutionType.pension:
        return 'Pension';
      case FinancialInstitutionType.other:
        return 'Other';
    }
  }

  /// Whether this institution type represents money owed BY the user
  /// (a liability, like `Loan`) rather than money the user holds (an
  /// asset). Mirrors the same asset/liability split PaySense's own
  /// `FinancialPlanningCalculator` already makes between `Wallet` and
  /// `Loan` — an AA-linked credit card or loan should be treated the
  /// same way once mapped, never counted as cash balance.
  bool get isLiability =>
      this == FinancialInstitutionType.creditCard || this == FinancialInstitutionType.loan;
}

/// One financial account as reported by an AA provider — e.g. a specific
/// HDFC savings account, or a specific credit card. This is NOT a
/// PaySense [Wallet]; PHASE 6 (future work) is what lets a user map one
/// of these onto a real `Wallet.id`, deliberately never automatically.
@immutable
class AccountAggregatorAccount {
  const AccountAggregatorAccount({
    required this.id,
    required this.displayName,
    required this.institutionName,
    required this.institutionType,
    required this.maskedIdentifier,
    this.balance,
    this.currencyCode = 'INR',
    this.lastSyncedAt,
    this.status = ConnectionStatus.connected,
    this.linkedWalletId,
  });

  /// Stable identifier from the AA provider's account-discovery response
  /// — NOT a PaySense id. Used as the join key for [AccountAggregatorTransaction.accountId].
  final String id;

  final String displayName;
  final String institutionName;
  final FinancialInstitutionType institutionType;

  /// Always masked, e.g. `"•••• 1234"` — never a full account/card
  /// number. See PHASE 12 (future work) — full identifiers are never
  /// stored or displayed.
  final String maskedIdentifier;

  /// The latest known balance/outstanding amount, if the provider
  /// reports one — always an unsigned magnitude; use
  /// [FinancialInstitutionType.isLiability] to interpret direction,
  /// exactly like PaySense's existing `Wallet.currentBalance` /
  /// `Loan.outstandingAmount` convention.
  final double? balance;
  final String currencyCode;
  final DateTime? lastSyncedAt;

  /// This account's own sync state. In practice only a subset of
  /// [ConnectionStatus] values are meaningful here (`connected`,
  /// `syncing`, `failed`, `partiallyConnected`) — the earlier
  /// pre-discovery states belong to the connection as a whole, not to an
  /// individual already-discovered account.
  final ConnectionStatus status;

  /// Set once the user has explicitly mapped this AA account onto a real
  /// PaySense `Wallet.id` (PHASE 6, future work). Null means
  /// "discovered but not yet mapped" — an unmapped account must never
  /// silently feed the ingestion pipeline.
  final String? linkedWalletId;

  bool get isMapped => linkedWalletId != null;

  AccountAggregatorAccount copyWith({
    String? displayName,
    String? institutionName,
    FinancialInstitutionType? institutionType,
    String? maskedIdentifier,
    double? balance,
    String? currencyCode,
    DateTime? lastSyncedAt,
    ConnectionStatus? status,
    String? linkedWalletId,
    bool clearLinkedWalletId = false,
  }) {
    return AccountAggregatorAccount(
      id: id,
      displayName: displayName ?? this.displayName,
      institutionName: institutionName ?? this.institutionName,
      institutionType: institutionType ?? this.institutionType,
      maskedIdentifier: maskedIdentifier ?? this.maskedIdentifier,
      balance: balance ?? this.balance,
      currencyCode: currencyCode ?? this.currencyCode,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      status: status ?? this.status,
      linkedWalletId: clearLinkedWalletId ? null : (linkedWalletId ?? this.linkedWalletId),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'displayName': displayName,
      'institutionName': institutionName,
      'institutionType': institutionType.name,
      'maskedIdentifier': maskedIdentifier,
      'balance': balance,
      'currencyCode': currencyCode,
      'lastSyncedAt': lastSyncedAt?.toIso8601String(),
      'status': status.name,
      'linkedWalletId': linkedWalletId,
    };
  }

  factory AccountAggregatorAccount.fromMap(Map<String, dynamic> map) {
    return AccountAggregatorAccount(
      id: map['id'] as String,
      displayName: map['displayName'] as String,
      institutionName: map['institutionName'] as String,
      institutionType: FinancialInstitutionType.values.firstWhere(
        (t) => t.name == map['institutionType'],
        orElse: () => FinancialInstitutionType.other,
      ),
      maskedIdentifier: map['maskedIdentifier'] as String,
      balance: (map['balance'] as num?)?.toDouble(),
      currencyCode: map['currencyCode'] as String? ?? 'INR',
      lastSyncedAt: map['lastSyncedAt'] != null ? DateTime.parse(map['lastSyncedAt'] as String) : null,
      status: ConnectionStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => ConnectionStatus.connected,
      ),
      linkedWalletId: map['linkedWalletId'] as String?,
    );
  }
}

/// One end-to-end connection to an AA provider — may cover several
/// [AccountAggregatorAccount]s discovered under a single consent.
@immutable
class AccountAggregatorConnection {
  const AccountAggregatorConnection({
    required this.connectionId,
    required this.providerId,
    required this.providerName,
    required this.status,
    required this.consentStatus,
    required this.createdAt,
    required this.updatedAt,
    this.lastSyncedAt,
    this.accounts = const [],
    this.errorMessage,
  });

  final String connectionId;

  /// The stable machine identifier of whichever [AccountAggregatorProvider]
  /// implementation created this connection (e.g. `"mock"`, `"finvu"`) —
  /// NEVER a display name. This is exactly how PHASE 3 (future work)'s
  /// mock connections stay unambiguously identifiable as `source = mock`:
  /// they're simply whatever a `MockAccountAggregatorProvider` reports as
  /// its own `providerId` (see PHASE 2).
  final String providerId;

  /// Human-readable name for display only (e.g. "Sandbox / Mock
  /// Provider", or a real AA/TSP's brand name later) — never used for
  /// logic, only [providerId] is.
  final String providerName;

  final ConnectionStatus status;
  final ConsentStatus consentStatus;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastSyncedAt;
  final List<AccountAggregatorAccount> accounts;

  /// A human-readable failure explanation (PHASE 16, future work) —
  /// never a raw exception/stack trace string.
  final String? errorMessage;

  bool get isMock => providerId == 'mock';

  AccountAggregatorConnection copyWith({
    ConnectionStatus? status,
    ConsentStatus? consentStatus,
    DateTime? updatedAt,
    DateTime? lastSyncedAt,
    List<AccountAggregatorAccount>? accounts,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AccountAggregatorConnection(
      connectionId: connectionId,
      providerId: providerId,
      providerName: providerName,
      status: status ?? this.status,
      consentStatus: consentStatus ?? this.consentStatus,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      accounts: accounts ?? this.accounts,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'connectionId': connectionId,
      'providerId': providerId,
      'providerName': providerName,
      'status': status.name,
      'consentStatus': consentStatus.name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'lastSyncedAt': lastSyncedAt?.toIso8601String(),
      'accounts': accounts.map((a) => a.toMap()).toList(),
      'errorMessage': errorMessage,
    };
  }

  factory AccountAggregatorConnection.fromMap(Map<String, dynamic> map) {
    return AccountAggregatorConnection(
      connectionId: map['connectionId'] as String,
      providerId: map['providerId'] as String,
      providerName: map['providerName'] as String,
      status: ConnectionStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => ConnectionStatus.disconnected,
      ),
      consentStatus: ConsentStatus.values.firstWhere(
        (s) => s.name == map['consentStatus'],
        orElse: () => ConsentStatus.created,
      ),
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
      lastSyncedAt: map['lastSyncedAt'] != null ? DateTime.parse(map['lastSyncedAt'] as String) : null,
      // BUG FIX: `a as Map<String, dynamic>` threw
      // "type '_Map<dynamic, dynamic>' is not a subtype of type
      // 'Map<String, dynamic>'" for any real (non-empty) connection —
      // Hive deserializes a NESTED map (this list's elements, inside the
      // outer 'accounts' list, inside the connection's own map) as a raw
      // `Map<dynamic, dynamic>`, not the exact generic type it was
      // written with. `Map<String, dynamic>.from(...)` re-types it
      // safely, exactly like the repository already does for the OUTER
      // map (see AccountAggregatorConnectionRepository.getAll/getById).
      accounts: ((map['accounts'] as List?) ?? const [])
          .map((a) => AccountAggregatorAccount.fromMap(Map<String, dynamic>.from(a as Map)))
          .toList(),
      errorMessage: map['errorMessage'] as String?,
    );
  }
}

/// Which side of the ledger an [AccountAggregatorTransaction] falls on —
/// deliberately the AA/banking-native `debit`/`credit` vocabulary, NOT
/// PaySense's own `IngestionTransactionType` (income/expense/transfer/
/// refund). Keeping these separate is what keeps this file
/// provider-independent: a future "AA adapter" (PHASE 5, not built in
/// this pass) is the one place that decides `debit -> expense` /
/// `credit -> income`, exactly mirroring how the existing SMS parser and
/// CSV parser already make that same translation at their own adapter
/// boundary.
enum AccountAggregatorTransactionDirection { debit, credit }

/// One raw transaction as reported by an AA provider for a specific
/// [AccountAggregatorAccount] — intentionally NOT a
/// `TransactionIngestionRecord`. See PHASE 5 (future work): a dedicated
/// AA adapter converts these into `TransactionIngestionRecord`s
/// (`source: TransactionSource.accountAggregator`) before anything
/// touches the normalize/validate/fingerprint/dedupe pipeline.
///
/// PRIVACY: structurally has no field for OTP/PIN/password/CVV/card
/// number/raw SMS body/credentials — same discipline as
/// `TransactionIngestionRecord` in the existing ingestion foundation.
@immutable
class AccountAggregatorTransaction {
  const AccountAggregatorTransaction({
    required this.id,
    required this.accountId,
    required this.amount,
    required this.direction,
    required this.transactionDate,
    this.narration,
    this.referenceNumber,
    this.mode,
    this.balanceAfterTransaction,
    this.currencyCode = 'INR',
  });

  /// The AA provider's own transaction id — becomes
  /// `TransactionIngestionRecord.sourceTransactionId` in PHASE 5.
  final String id;

  /// Joins to [AccountAggregatorAccount.id] — NOT a PaySense `Wallet.id`.
  final String accountId;

  /// Always an unsigned magnitude; [direction] carries the sign meaning.
  final double amount;
  final AccountAggregatorTransactionDirection direction;
  final DateTime transactionDate;

  /// The provider's transaction narration/description — the closest
  /// analogue to `TransactionIngestionRecord.description`/`merchant`.
  final String? narration;

  /// A bank reference/UTR number if the provider supplies one — becomes
  /// `TransactionIngestionRecord.referenceId` in PHASE 5, letting a
  /// strong-fingerprint match happen exactly like a CSV row with a UTR
  /// column.
  final String? referenceNumber;

  /// Informational payment rail only (e.g. `"UPI"`, `"NEFT"`, `"IMPS"`)
  /// — never a credential, never sensitive.
  final String? mode;
  final double? balanceAfterTransaction;
  final String currencyCode;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'accountId': accountId,
      'amount': amount,
      'direction': direction.name,
      'transactionDate': transactionDate.toIso8601String(),
      'narration': narration,
      'referenceNumber': referenceNumber,
      'mode': mode,
      'balanceAfterTransaction': balanceAfterTransaction,
      'currencyCode': currencyCode,
    };
  }
}

/// The outcome of one [AccountAggregatorProvider.syncFinancialData] call
/// — deliberately carries RAW [AccountAggregatorTransaction]s, not
/// `TransactionIngestionRecord`s (see that class's doc comment). Also
/// carries the updated [AccountAggregatorAccount] snapshots (fresh
/// balances/`lastSyncedAt`) so the caller can persist connection state
/// without a second round-trip.
@immutable
class AccountAggregatorSyncResult {
  const AccountAggregatorSyncResult({
    required this.connectionId,
    required this.syncedAt,
    required this.accounts,
    this.transactionsByAccountId = const {},
    this.isPartial = false,
    this.warnings = const [],
    this.errorMessage,
  });

  final String connectionId;
  final DateTime syncedAt;

  /// Refreshed account snapshots (balance/lastSyncedAt/status) for every
  /// account this sync touched.
  final List<AccountAggregatorAccount> accounts;

  /// Raw transactions fetched, keyed by [AccountAggregatorAccount.id].
  final Map<String, List<AccountAggregatorTransaction>> transactionsByAccountId;

  /// True when some accounts synced successfully but at least one did
  /// not (PHASE 16's "partial account fetch" / "partial transaction
  /// fetch" cases, future work) — the caller must never treat a partial
  /// result as a full failure, nor silently treat it as full success.
  final bool isPartial;

  final List<String> warnings;
  final String? errorMessage;

  int get totalTransactionCount =>
      transactionsByAccountId.values.fold(0, (sum, list) => sum + list.length);
}

/// Structured failure for [AccountAggregatorProvider] calls — reserved
/// for exceptional/transport-level failures (network, provider outage).
/// Expected "soft" outcomes (consent rejected/expired, partial sync) are
/// represented through [AccountAggregatorConnection]/[AccountAggregatorSyncResult]
/// fields instead of exceptions, so callers aren't forced into try/catch
/// for ordinary consent-flow outcomes.
class AccountAggregatorException implements Exception {
  const AccountAggregatorException(this.code, this.message);

  final AccountAggregatorErrorCode code;

  /// Always a human-readable message — never a raw stack trace or
  /// vendor-specific error payload (PHASE 16, future work).
  final String message;

  @override
  String toString() => 'AccountAggregatorException(${code.name}): $message';
}

enum AccountAggregatorErrorCode {
  networkTimeout,
  providerUnavailable,
  institutionNotSupported,
  malformedData,
  invalidConnection,
  unknown,

  /// PRODUCTION HARDENING — the selected [AccountAggregatorEnvironment]
  /// requires configuration (base URL, client id, etc.) that hasn't been
  /// supplied — see `account_aggregator_config.dart`. Never silently
  /// falls back to mock data when this occurs.
  configurationMissing,

  /// The configured/attempted provider has no real implementation yet
  /// (the production stub) — see `production_account_aggregator_provider.dart`.
  notImplemented,

  /// Authentication with the AA/TSP or PaySense's own backend boundary
  /// failed — never carries the credential itself.
  authenticationFailed,
}
