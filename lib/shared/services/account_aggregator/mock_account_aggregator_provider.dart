import 'account_aggregator_models.dart';
import 'account_aggregator_provider_interface.dart';

/// ACCOUNT AGGREGATOR / ONE-TAP CONNECT — PHASE 3. A deterministic,
/// fully offline, in-memory implementation of [AccountAggregatorProvider]
/// for development, UI work, and automated tests.
///
/// THIS IS NOT A REAL BANK CONNECTION. Every connection this provider
/// creates reports `providerId == 'mock'`
/// ([AccountAggregatorConnection.isMock]) so calling code can always tell
/// mock data apart from a real, regulated AA/TSP provider once one exists
/// (PHASE 17, future work).
///
/// DETERMINISM: every account/transaction this provider returns is a pure
/// function of [referenceDate] and the connection's own stored inputs
/// (`institutionTypes`, `historyDuration`) — never `DateTime.now()`, never
/// `Random()`, never a network call. The same inputs always produce the
/// same output, including across repeated `syncFinancialData` calls (the
/// exact guarantee PHASE 11's duplicate-safety work, future, will rely
/// on).
///
/// STATE: this provider holds its connections in a private instance-level
/// map — controlled, non-global mutable state scoped to one provider
/// instance, not persisted anywhere (that's PHASE 4/6, future work).
///
/// TEST/DEV CONTROLS: [AccountAggregatorProvider] deliberately has no
/// production method for a human to "approve" a consent (that happens on
/// the AA provider's own web/app flow in real life). This mock exposes
/// [approveConsent], [rejectConsent], and [expireConsent] as additional
/// public methods — NOT part of the production interface — purely so
/// tests and future UI development can drive the consent lifecycle
/// without a real approval flow. They are synchronous (no simulated
/// network) and clearly documented as mock-only.
class MockAccountAggregatorProvider implements AccountAggregatorProvider, AccountAggregatorDevControls {
  MockAccountAggregatorProvider({
    DateTime? referenceDate,
    this.failureMode = MockAccountAggregatorFailureMode.none,
  }) : referenceDate = referenceDate ?? DateTime(2026, 8, 26);

  /// The mock's notion of "now" — every generated date is computed
  /// relative to this, never to the real wall clock, so tests are
  /// reproducible regardless of when they run.
  final DateTime referenceDate;

  /// Configures which deterministic failure this provider simulates.
  /// Mutable (scoped to this instance only) so a single test can exercise
  /// multiple failure scenarios without constructing a new provider each
  /// time. See [MockAccountAggregatorFailureMode] for exactly what each
  /// value does.
  MockAccountAggregatorFailureMode failureMode;

  @override
  String get providerId => 'mock';

  @override
  String get displayName => 'Sandbox / Mock Provider';

  final Map<String, AccountAggregatorConnection> _connections = {};
  final Map<String, List<FinancialInstitutionType>> _institutionTypesByConnection = {};
  final Map<String, Duration> _historyDurationByConnection = {};

  // ---------------------------------------------------------------------
  // AccountAggregatorProvider
  // ---------------------------------------------------------------------

  @override
  Future<AccountAggregatorConnection> createConsent({
    required String userId,
    required List<FinancialInstitutionType> institutionTypes,
    required Duration historyDuration,
  }) async {
    _checkProviderAvailability();

    if (institutionTypes.isEmpty) {
      throw const AccountAggregatorException(
        AccountAggregatorErrorCode.institutionNotSupported,
        'No institution types were requested.',
      );
    }

    // Deterministic: the SAME (userId, institutionTypes) always maps to
    // the SAME connectionId — no random UUID, no incrementing counter.
    final connectionId = _deterministicConnectionId(userId, institutionTypes);

    var status = ConnectionStatus.awaitingConsent;
    var consentStatus = ConsentStatus.pending;
    String? errorMessage;

    // A provider pre-configured with a "soft" consent-outcome failure
    // mode reports that outcome immediately, as if the AA/bank side had
    // already decided — this lets a test assert the rejected/expired/
    // revoked code paths without manually driving the lifecycle first.
    switch (failureMode) {
      case MockAccountAggregatorFailureMode.consentRejected:
        status = ConnectionStatus.failed;
        consentStatus = ConsentStatus.rejected;
        errorMessage = 'The user did not approve this connection.';
      case MockAccountAggregatorFailureMode.consentExpired:
        status = ConnectionStatus.failed;
        consentStatus = ConsentStatus.expired;
        errorMessage = 'This consent has expired. Please reconnect your accounts.';
      case MockAccountAggregatorFailureMode.consentRevoked:
        status = ConnectionStatus.revoked;
        consentStatus = ConsentStatus.revoked;
        errorMessage = 'Access to this connection was revoked.';
      default:
        break;
    }

    final connection = AccountAggregatorConnection(
      connectionId: connectionId,
      providerId: providerId,
      providerName: displayName,
      status: status,
      consentStatus: consentStatus,
      createdAt: referenceDate,
      updatedAt: referenceDate,
      errorMessage: errorMessage,
    );

    _connections[connectionId] = connection;
    _institutionTypesByConnection[connectionId] = List.unmodifiable(institutionTypes);
    _historyDurationByConnection[connectionId] = historyDuration;

    return connection;
  }

  @override
  Future<AccountAggregatorConnection> getConsentStatus({required String connectionId}) async {
    _checkProviderAvailability();
    return _requireConnection(connectionId);
  }

  @override
  Future<List<AccountAggregatorAccount>> fetchAccounts({required String connectionId}) async {
    _checkProviderAvailability();
    final connection = _requireConnection(connectionId);
    _requireApprovedConsent(connection);

    final accounts = _accountsForConnection(connectionId);

    // Discovering accounts is a real, observable step of the lifecycle
    // (consentGranted -> fetching -> ... ) — record it, but do not claim
    // "connected" yet: transactions haven't been synced.
    _connections[connectionId] = connection.copyWith(
      status: ConnectionStatus.fetching,
      accounts: accounts,
      updatedAt: referenceDate,
    );

    return accounts;
  }

  @override
  Future<AccountAggregatorSyncResult> syncFinancialData({
    required String connectionId,
    DateTime? since,
  }) async {
    _checkProviderAvailability();
    final connection = _requireConnection(connectionId);
    _requireApprovedConsent(connection);

    final fullAccounts = _accountsForConnection(connectionId);
    final isPartialAccounts = failureMode == MockAccountAggregatorFailureMode.partialAccountResponse;
    // Deterministic drop: always the LAST account in the (stably
    // ordered) catalog — never random, never "whichever happens to fail".
    final accounts = isPartialAccounts && fullAccounts.length > 1
        ? fullAccounts.sublist(0, fullAccounts.length - 1)
        : fullAccounts;

    final historyDuration = _historyDurationByConnection[connectionId] ?? const Duration(days: 180);
    final earliestAllowed = referenceDate.subtract(historyDuration);
    final effectiveSince = since != null && since.isAfter(earliestAllowed) ? since : earliestAllowed;

    final warnings = <String>[];
    var isPartial = isPartialAccounts;
    if (isPartialAccounts) {
      warnings.add('Some accounts could not be retrieved.');
    }

    final transactionsByAccountId = <String, List<AccountAggregatorTransaction>>{};
    for (final account in accounts) {
      var transactions = _transactionsForAccount(account.id)
          .where((t) => !t.transactionDate.isBefore(effectiveSince))
          .toList();

      switch (failureMode) {
        case MockAccountAggregatorFailureMode.emptyTransactionHistory:
          // A valid, non-partial outcome — a brand new account with no
          // history yet is not an error (PHASE 13's "empty data" rule).
          transactions = const [];
        case MockAccountAggregatorFailureMode.partialTransactionResponse:
          if (transactions.length > 1) {
            transactions = transactions.sublist(0, transactions.length ~/ 2);
            isPartial = true;
            if (!warnings.contains('Some transactions could not be retrieved.')) {
              warnings.add('Some transactions could not be retrieved.');
            }
          }
        case MockAccountAggregatorFailureMode.malformedTransactionData:
          if (transactions.isNotEmpty) {
            transactions = [
              for (var i = 0; i < transactions.length; i++)
                i == 0
                    ? AccountAggregatorTransaction(
                        id: transactions[i].id,
                        accountId: transactions[i].accountId,
                        amount: 0,
                        direction: transactions[i].direction,
                        transactionDate: transactions[i].transactionDate,
                        narration: null,
                        referenceNumber: transactions[i].referenceNumber,
                        currencyCode: transactions[i].currencyCode,
                      )
                    : transactions[i],
            ];
            isPartial = true;
            if (!warnings.contains('Some transaction data could not be fully parsed.')) {
              warnings.add('Some transaction data could not be fully parsed.');
            }
          }
        default:
          break;
      }

      transactionsByAccountId[account.id] = transactions;
    }

    final syncedAccounts = [for (final a in accounts) a.copyWith(lastSyncedAt: referenceDate)];

    _connections[connectionId] = connection.copyWith(
      status: isPartial ? ConnectionStatus.partiallyConnected : ConnectionStatus.connected,
      accounts: syncedAccounts,
      lastSyncedAt: referenceDate,
      updatedAt: referenceDate,
      clearError: true,
    );

    return AccountAggregatorSyncResult(
      connectionId: connectionId,
      syncedAt: referenceDate,
      accounts: syncedAccounts,
      transactionsByAccountId: transactionsByAccountId,
      isPartial: isPartial,
      warnings: warnings,
    );
  }

  @override
  Future<AccountAggregatorConnection> revokeConsent({required String connectionId}) async {
    _checkProviderAvailability();
    final connection = _requireConnection(connectionId);
    final updated = connection.copyWith(
      status: ConnectionStatus.revoked,
      consentStatus: ConsentStatus.revoked,
      updatedAt: referenceDate,
    );
    _connections[connectionId] = updated;
    return updated;
  }

  // ---------------------------------------------------------------------
  // Mock-only test/dev controls — NOT part of AccountAggregatorProvider.
  // ---------------------------------------------------------------------

  /// Reports [ConnectionStatus.disconnected] for any id that has never
  /// had [createConsent] called for it. There is no
  /// [AccountAggregatorConnection] object to query before that point —
  /// this is the one place "the initial state is disconnected" is
  /// actually observable.
  ConnectionStatus statusFor(String connectionId) =>
      _connections[connectionId]?.status ?? ConnectionStatus.disconnected;

  /// Simulates the user approving the consent request on the AA
  /// provider's own flow. Synchronous — this is a test control, not a
  /// network operation.
  @override
  AccountAggregatorConnection approveConsent(String connectionId) {
    final connection = _requireConnection(connectionId);
    if (connection.consentStatus != ConsentStatus.pending) {
      throw StateError(
        'approveConsent: connection "$connectionId" is not awaiting consent '
        '(current consentStatus: ${connection.consentStatus.name}).',
      );
    }
    final updated = connection.copyWith(
      status: ConnectionStatus.consentGranted,
      consentStatus: ConsentStatus.approved,
      updatedAt: referenceDate,
    );
    _connections[connectionId] = updated;
    return updated;
  }

  /// Simulates the user rejecting the consent request.
  @override
  AccountAggregatorConnection rejectConsent(String connectionId) {
    final connection = _requireConnection(connectionId);
    if (connection.consentStatus != ConsentStatus.pending) {
      throw StateError(
        'rejectConsent: connection "$connectionId" is not awaiting consent '
        '(current consentStatus: ${connection.consentStatus.name}).',
      );
    }
    final updated = connection.copyWith(
      status: ConnectionStatus.failed,
      consentStatus: ConsentStatus.rejected,
      updatedAt: referenceDate,
      errorMessage: 'The user did not approve this connection.',
    );
    _connections[connectionId] = updated;
    return updated;
  }

  /// Simulates a previously granted/connected consent expiring — the
  /// [ConnectionStatus] enum has no dedicated "expired" value, so this
  /// maps to [ConnectionStatus.failed] (the closest existing terminal
  /// state) while [ConsentStatus.expired] carries the specific reason,
  /// per the existing model's "don't invent a new state" constraint.
  @override
  AccountAggregatorConnection expireConsent(String connectionId) {
    final connection = _requireConnection(connectionId);
    if (connection.consentStatus != ConsentStatus.approved) {
      throw StateError(
        'expireConsent: connection "$connectionId" has no active consent to expire '
        '(current consentStatus: ${connection.consentStatus.name}).',
      );
    }
    final updated = connection.copyWith(
      status: ConnectionStatus.failed,
      consentStatus: ConsentStatus.expired,
      updatedAt: referenceDate,
      errorMessage: 'This consent has expired. Please reconnect your accounts.',
    );
    _connections[connectionId] = updated;
    return updated;
  }

  // ---------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------

  void _checkProviderAvailability() {
    switch (failureMode) {
      case MockAccountAggregatorFailureMode.providerUnavailable:
        throw const AccountAggregatorException(
          AccountAggregatorErrorCode.providerUnavailable,
          'Your bank connection is temporarily unavailable. Your existing PaySense data is safe.',
        );
      case MockAccountAggregatorFailureMode.networkTimeout:
        throw const AccountAggregatorException(
          AccountAggregatorErrorCode.networkTimeout,
          'The connection timed out. Please try again.',
        );
      default:
        return;
    }
  }

  AccountAggregatorConnection _requireConnection(String connectionId) {
    final connection = _connections[connectionId];
    if (connection == null) {
      throw AccountAggregatorException(
        AccountAggregatorErrorCode.invalidConnection,
        'No connection found for id "$connectionId".',
      );
    }
    return connection;
  }

  void _requireApprovedConsent(AccountAggregatorConnection connection) {
    if (connection.consentStatus != ConsentStatus.approved) {
      throw AccountAggregatorException(
        AccountAggregatorErrorCode.invalidConnection,
        'This connection has not been approved yet, or access was rejected, expired, or revoked '
        '(current consentStatus: ${connection.consentStatus.name}).',
      );
    }
  }

  /// Deterministic connection id — a pure function of the inputs, never a
  /// random UUID, so the SAME (userId, institutionTypes) pair always
  /// produces the SAME connection.
  String _deterministicConnectionId(String userId, List<FinancialInstitutionType> institutionTypes) {
    final sortedTypeNames = institutionTypes.map((t) => t.name).toList()..sort();
    return 'mock-conn-$userId-${sortedTypeNames.join('-')}';
  }

  List<AccountAggregatorAccount> _accountsForConnection(String connectionId) {
    final requestedTypes = _institutionTypesByConnection[connectionId] ?? const [];
    return _fullAccountCatalog(referenceDate)
        .where((account) => requestedTypes.contains(account.institutionType))
        .toList();
  }

  /// The complete deterministic set of synthetic accounts this mock can
  /// ever report — two institutions, two product types each, covering
  /// both assets and liabilities (PHASE 6, future work, needs this
  /// variety to test wallet mapping against a liability account).
  static List<AccountAggregatorAccount> _fullAccountCatalog(DateTime referenceDate) {
    return [
      AccountAggregatorAccount(
        id: 'MOCK-ACC-HDFC-SAVINGS',
        displayName: 'HDFC Savings',
        institutionName: 'HDFC Bank',
        institutionType: FinancialInstitutionType.bank,
        maskedIdentifier: '•••• 1234',
        balance: 182450,
        lastSyncedAt: referenceDate,
      ),
      AccountAggregatorAccount(
        id: 'MOCK-ACC-ICICI-SAVINGS',
        displayName: 'ICICI Savings',
        institutionName: 'ICICI Bank',
        institutionType: FinancialInstitutionType.bank,
        maskedIdentifier: '•••• 7821',
        balance: 72300,
        lastSyncedAt: referenceDate,
      ),
      AccountAggregatorAccount(
        id: 'MOCK-ACC-HDFC-CREDITCARD',
        displayName: 'HDFC Credit Card',
        institutionName: 'HDFC Bank',
        institutionType: FinancialInstitutionType.creditCard,
        maskedIdentifier: '•••• 4455',
        balance: 18400,
        lastSyncedAt: referenceDate,
      ),
      AccountAggregatorAccount(
        id: 'MOCK-ACC-ICICI-PERSONALLOAN',
        displayName: 'ICICI Personal Loan',
        institutionName: 'ICICI Bank',
        institutionType: FinancialInstitutionType.loan,
        maskedIdentifier: '•••• 9012',
        balance: 482000,
        lastSyncedAt: referenceDate,
      ),
    ];
  }

  /// Deterministic transaction history for one mock account, expressed
  /// relative to [referenceDate] — same account id + same referenceDate
  /// always yields the identical list, every call, forever.
  List<AccountAggregatorTransaction> _transactionsForAccount(String accountId) {
    switch (accountId) {
      case 'MOCK-ACC-HDFC-SAVINGS':
        return [
          // Salary credited on the 1st, for the current + two prior
          // months — a recurring-looking income pattern.
          AccountAggregatorTransaction(
            id: 'MOCK-HDFC-000001',
            accountId: accountId,
            amount: 72000,
            direction: AccountAggregatorTransactionDirection.credit,
            transactionDate: _monthsBefore(referenceDate, 2, day: 1),
            narration: 'Salary',
            referenceNumber: 'MOCK-HDFC-000001',
            mode: 'NEFT',
          ),
          AccountAggregatorTransaction(
            id: 'MOCK-HDFC-000002',
            accountId: accountId,
            amount: 72000,
            direction: AccountAggregatorTransactionDirection.credit,
            transactionDate: _monthsBefore(referenceDate, 1, day: 1),
            narration: 'Salary',
            referenceNumber: 'MOCK-HDFC-000002',
            mode: 'NEFT',
          ),
          AccountAggregatorTransaction(
            id: 'MOCK-HDFC-000003',
            accountId: accountId,
            amount: 72000,
            direction: AccountAggregatorTransactionDirection.credit,
            transactionDate: _monthsBefore(referenceDate, 0, day: 1),
            narration: 'Salary',
            referenceNumber: 'MOCK-HDFC-000003',
            mode: 'NEFT',
          ),
          // Rent debited on the 3rd, recurring.
          AccountAggregatorTransaction(
            id: 'MOCK-HDFC-000004',
            accountId: accountId,
            amount: 18000,
            direction: AccountAggregatorTransactionDirection.debit,
            transactionDate: _monthsBefore(referenceDate, 1, day: 3),
            narration: 'Rent',
            referenceNumber: 'MOCK-HDFC-000004',
            mode: 'UPI',
          ),
          AccountAggregatorTransaction(
            id: 'MOCK-HDFC-000005',
            accountId: accountId,
            amount: 18000,
            direction: AccountAggregatorTransactionDirection.debit,
            transactionDate: _monthsBefore(referenceDate, 0, day: 3),
            narration: 'Rent',
            referenceNumber: 'MOCK-HDFC-000005',
            mode: 'UPI',
          ),
          // Electricity, recurring.
          AccountAggregatorTransaction(
            id: 'MOCK-HDFC-000006',
            accountId: accountId,
            amount: 2340,
            direction: AccountAggregatorTransactionDirection.debit,
            transactionDate: _monthsBefore(referenceDate, 0, day: 10),
            narration: 'Electricity Bill',
            referenceNumber: 'MOCK-HDFC-000006',
            mode: 'UPI',
          ),
          // Two same-day Swiggy orders — deliberately included so future
          // ingestion-safety tests (PHASE 5/11) have a genuine same-day,
          // same-merchant, DIFFERENT-amount pair to work with.
          AccountAggregatorTransaction(
            id: 'MOCK-HDFC-000007',
            accountId: accountId,
            amount: 680,
            direction: AccountAggregatorTransactionDirection.debit,
            transactionDate: _monthsBefore(referenceDate, 0, day: 12),
            narration: 'Swiggy',
            referenceNumber: 'MOCK-HDFC-000007',
            mode: 'UPI',
          ),
          AccountAggregatorTransaction(
            id: 'MOCK-HDFC-000008',
            accountId: accountId,
            amount: 450,
            direction: AccountAggregatorTransactionDirection.debit,
            transactionDate: _monthsBefore(referenceDate, 0, day: 12),
            narration: 'Swiggy',
            referenceNumber: 'MOCK-HDFC-000008',
            mode: 'UPI',
          ),
          AccountAggregatorTransaction(
            id: 'MOCK-HDFC-000009',
            accountId: accountId,
            amount: 2499,
            direction: AccountAggregatorTransactionDirection.debit,
            transactionDate: _monthsBefore(referenceDate, 0, day: 15),
            narration: 'Amazon',
            referenceNumber: 'MOCK-HDFC-000009',
            mode: 'UPI',
          ),
        ];
      case 'MOCK-ACC-ICICI-SAVINGS':
        return [
          AccountAggregatorTransaction(
            id: 'MOCK-ICICI-000001',
            accountId: accountId,
            amount: 15000,
            direction: AccountAggregatorTransactionDirection.credit,
            transactionDate: _monthsBefore(referenceDate, 0, day: 5),
            narration: 'Freelance Payment',
            referenceNumber: 'MOCK-ICICI-000001',
            mode: 'UPI',
          ),
          AccountAggregatorTransaction(
            id: 'MOCK-ICICI-000002',
            accountId: accountId,
            amount: 3200,
            direction: AccountAggregatorTransactionDirection.debit,
            transactionDate: _monthsBefore(referenceDate, 0, day: 8),
            narration: 'Groceries',
            referenceNumber: 'MOCK-ICICI-000002',
            mode: 'UPI',
          ),
        ];
      case 'MOCK-ACC-HDFC-CREDITCARD':
        return [
          AccountAggregatorTransaction(
            id: 'MOCK-HDFC-CC-000001',
            accountId: accountId,
            amount: 2499,
            direction: AccountAggregatorTransactionDirection.debit,
            transactionDate: _monthsBefore(referenceDate, 0, day: 15),
            narration: 'Amazon',
            referenceNumber: 'MOCK-HDFC-CC-000001',
            mode: 'CARD',
          ),
          AccountAggregatorTransaction(
            id: 'MOCK-HDFC-CC-000002',
            accountId: accountId,
            amount: 5000,
            direction: AccountAggregatorTransactionDirection.credit,
            transactionDate: _monthsBefore(referenceDate, 0, day: 20),
            narration: 'Credit Card Payment',
            referenceNumber: 'MOCK-HDFC-CC-000002',
            mode: 'UPI',
          ),
        ];
      case 'MOCK-ACC-ICICI-PERSONALLOAN':
        return [
          AccountAggregatorTransaction(
            id: 'MOCK-ICICI-LOAN-000001',
            accountId: accountId,
            amount: 14500,
            direction: AccountAggregatorTransactionDirection.debit,
            transactionDate: _monthsBefore(referenceDate, 1, day: 5),
            narration: 'Loan EMI',
            referenceNumber: 'MOCK-ICICI-LOAN-000001',
            mode: 'NACH',
          ),
          AccountAggregatorTransaction(
            id: 'MOCK-ICICI-LOAN-000002',
            accountId: accountId,
            amount: 14500,
            direction: AccountAggregatorTransactionDirection.debit,
            transactionDate: _monthsBefore(referenceDate, 0, day: 5),
            narration: 'Loan EMI',
            referenceNumber: 'MOCK-ICICI-LOAN-000002',
            mode: 'NACH',
          ),
        ];
      default:
        return const [];
    }
  }

  /// [months] months before [date], landing on [day] of that month.
  /// Only ever called with small offsets (0, 1, 2) so no year-rollover
  /// handling is needed beyond what [DateTime]'s constructor already
  /// does correctly for a negative month arithmetic result.
  static DateTime _monthsBefore(DateTime date, int months, {required int day}) {
    return DateTime(date.year, date.month - months, day);
  }
}

/// PHASE 3 — deterministic development failure simulations. `none` is
/// always the default; every other value represents one of the required
/// mock failure scenarios. See [MockAccountAggregatorProvider]'s method
/// implementations for exactly where/how each one is applied.
enum MockAccountAggregatorFailureMode {
  none,
  consentRejected,
  providerUnavailable,
  networkTimeout,
  consentExpired,
  consentRevoked,
  malformedTransactionData,
  partialAccountResponse,
  partialTransactionResponse,
  emptyTransactionHistory,
}
