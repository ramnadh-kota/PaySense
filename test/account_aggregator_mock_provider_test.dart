import 'package:flutter_test/flutter_test.dart';
import 'package:paysense/shared/services/account_aggregator/account_aggregator_models.dart';
import 'package:paysense/shared/services/account_aggregator/account_aggregator_provider_interface.dart';
import 'package:paysense/shared/services/account_aggregator/account_aggregator_service.dart';
import 'package:paysense/shared/services/account_aggregator/mock_account_aggregator_provider.dart';

final _referenceDate = DateTime(2026, 8, 26);
const _userId = 'test-user-1';
const _allTypes = [
  FinancialInstitutionType.bank,
  FinancialInstitutionType.creditCard,
  FinancialInstitutionType.loan,
];

MockAccountAggregatorProvider _provider({
  MockAccountAggregatorFailureMode failureMode = MockAccountAggregatorFailureMode.none,
}) {
  return MockAccountAggregatorProvider(referenceDate: _referenceDate, failureMode: failureMode);
}

Future<AccountAggregatorConnection> _createAndApprove(
  MockAccountAggregatorProvider provider, {
  List<FinancialInstitutionType> types = _allTypes,
}) async {
  final connection = await provider.createConsent(
    userId: _userId,
    institutionTypes: types,
    historyDuration: const Duration(days: 180),
  );
  return provider.approveConsent(connection.connectionId);
}

void main() {
  group('1. Interface conformance', () {
    test('MockAccountAggregatorProvider implements AccountAggregatorProvider', () {
      expect(_provider(), isA<AccountAggregatorProvider>());
    });

    test('reports its own providerId/displayName, never a vendor name', () {
      final provider = _provider();
      expect(provider.providerId, 'mock');
      expect(provider.displayName, isNotEmpty);
    });
  });

  group('2-8. Consent lifecycle', () {
    test('2. initial state is disconnected before any consent is created', () {
      final provider = _provider();
      expect(provider.statusFor('never-created'), ConnectionStatus.disconnected);
    });

    test('3. consent can be created', () async {
      final provider = _provider();
      final connection = await provider.createConsent(
        userId: _userId,
        institutionTypes: _allTypes,
        historyDuration: const Duration(days: 180),
      );
      expect(connection.connectionId, isNotEmpty);
      expect(connection.status, ConnectionStatus.awaitingConsent);
      expect(connection.isMock, isTrue);
    });

    test('4. consent starts pending', () async {
      final provider = _provider();
      final connection = await provider.createConsent(
        userId: _userId,
        institutionTypes: _allTypes,
        historyDuration: const Duration(days: 180),
      );
      expect(connection.consentStatus, ConsentStatus.pending);
    });

    test('5. consent approval works', () async {
      final provider = _provider();
      final connection = await provider.createConsent(
        userId: _userId,
        institutionTypes: _allTypes,
        historyDuration: const Duration(days: 180),
      );
      final approved = provider.approveConsent(connection.connectionId);
      expect(approved.consentStatus, ConsentStatus.approved);
      expect(approved.status, ConnectionStatus.consentGranted);
    });

    test('6. consent rejection works', () async {
      final provider = _provider();
      final connection = await provider.createConsent(
        userId: _userId,
        institutionTypes: _allTypes,
        historyDuration: const Duration(days: 180),
      );
      final rejected = provider.rejectConsent(connection.connectionId);
      expect(rejected.consentStatus, ConsentStatus.rejected);
      expect(rejected.status, ConnectionStatus.failed);
      expect(rejected.errorMessage, isNotNull);
    });

    test('7. consent expiration works', () async {
      final provider = _provider();
      final connection = await _createAndApprove(provider);
      final expired = provider.expireConsent(connection.connectionId);
      expect(expired.consentStatus, ConsentStatus.expired);
      expect(expired.status, ConnectionStatus.failed);
    });

    test('8. consent revocation works', () async {
      final provider = _provider();
      final connection = await _createAndApprove(provider);
      final revoked = await provider.revokeConsent(connectionId: connection.connectionId);
      expect(revoked.consentStatus, ConsentStatus.revoked);
      expect(revoked.status, ConnectionStatus.revoked);
    });

    test('never automatically approves a newly created consent', () async {
      final provider = _provider();
      final connection = await provider.createConsent(
        userId: _userId,
        institutionTypes: _allTypes,
        historyDuration: const Duration(days: 180),
      );
      expect(connection.consentStatus, isNot(ConsentStatus.approved));
      expect(connection.status, isNot(ConnectionStatus.connected));
    });
  });

  group('9-12. Account and transaction access gating', () {
    test('9. account discovery works after consent', () async {
      final provider = _provider();
      final connection = await _createAndApprove(provider);
      final accounts = await provider.fetchAccounts(connectionId: connection.connectionId);
      expect(accounts, isNotEmpty);
    });

    test('10. account discovery is blocked before consent is approved', () async {
      final provider = _provider();
      final connection = await provider.createConsent(
        userId: _userId,
        institutionTypes: _allTypes,
        historyDuration: const Duration(days: 180),
      );
      expect(
        () => provider.fetchAccounts(connectionId: connection.connectionId),
        throwsA(isA<AccountAggregatorException>()),
      );
    });

    test('11. transaction fetch (sync) works after consent', () async {
      final provider = _provider();
      final connection = await _createAndApprove(provider);
      final result = await provider.syncFinancialData(connectionId: connection.connectionId);
      expect(result.totalTransactionCount, greaterThan(0));
    });

    test('12. transaction fetch is blocked before consent is approved', () async {
      final provider = _provider();
      final connection = await provider.createConsent(
        userId: _userId,
        institutionTypes: _allTypes,
        historyDuration: const Duration(days: 180),
      );
      expect(
        () => provider.syncFinancialData(connectionId: connection.connectionId),
        throwsA(isA<AccountAggregatorException>()),
      );
    });
  });

  group('13-14. Sync correctness and determinism', () {
    test('13. sync succeeds with no error and full accounts', () async {
      final provider = _provider();
      final connection = await _createAndApprove(provider);
      final result = await provider.syncFinancialData(connectionId: connection.connectionId);
      expect(result.errorMessage, isNull);
      expect(result.isPartial, isFalse);
      expect(result.accounts.length, 4); // 2 bank accounts + 1 credit card + 1 loan
    });

    test('14. sync result is deterministic across repeated calls', () async {
      final providerA = _provider();
      final connectionA = await _createAndApprove(providerA);
      final resultA = await providerA.syncFinancialData(connectionId: connectionA.connectionId);

      final providerB = _provider();
      final connectionB = await _createAndApprove(providerB);
      final resultB = await providerB.syncFinancialData(connectionId: connectionB.connectionId);

      expect(resultA.totalTransactionCount, resultB.totalTransactionCount);
      final txA = resultA.transactionsByAccountId['MOCK-ACC-HDFC-SAVINGS']!;
      final txB = resultB.transactionsByAccountId['MOCK-ACC-HDFC-SAVINGS']!;
      expect(txA.length, txB.length);
      for (var i = 0; i < txA.length; i++) {
        expect(txA[i].id, txB[i].id);
        expect(txA[i].amount, txB[i].amount);
        expect(txA[i].transactionDate, txB[i].transactionDate);
        expect(txA[i].referenceNumber, txB[i].referenceNumber);
      }

      // Calling sync AGAIN on the SAME provider/connection must also
      // reproduce identical results — the critical guarantee future
      // duplicate-safety (Phase 11) work will depend on.
      final resultA2 = await providerA.syncFinancialData(connectionId: connectionA.connectionId);
      expect(resultA2.totalTransactionCount, resultA.totalTransactionCount);
    });
  });

  group('15-17. Mock institution/account content', () {
    test('15. an HDFC Bank account exists', () async {
      final provider = _provider();
      final connection = await _createAndApprove(provider);
      final accounts = await provider.fetchAccounts(connectionId: connection.connectionId);
      expect(accounts.any((a) => a.institutionName == 'HDFC Bank'), isTrue);
    });

    test('16. an ICICI Bank account exists', () async {
      final provider = _provider();
      final connection = await _createAndApprove(provider);
      final accounts = await provider.fetchAccounts(connectionId: connection.connectionId);
      expect(accounts.any((a) => a.institutionName == 'ICICI Bank'), isTrue);
    });

    test('17. a liability account (credit card / loan) exists', () async {
      final provider = _provider();
      final connection = await _createAndApprove(provider);
      final accounts = await provider.fetchAccounts(connectionId: connection.connectionId);
      expect(accounts.any((a) => a.institutionType.isLiability), isTrue);
    });

    test('accounts are filtered by the institution types requested at consent time', () async {
      final provider = _provider();
      final connection = await _createAndApprove(provider, types: const [FinancialInstitutionType.bank]);
      final accounts = await provider.fetchAccounts(connectionId: connection.connectionId);
      expect(accounts.every((a) => a.institutionType == FinancialInstitutionType.bank), isTrue);
      expect(accounts.length, 2); // HDFC + ICICI savings only
    });

    test('requesting an institution type with no matching mock account returns an empty (valid) list', () async {
      final provider = _provider();
      final connection = await _createAndApprove(provider, types: const [FinancialInstitutionType.mutualFund]);
      final accounts = await provider.fetchAccounts(connectionId: connection.connectionId);
      expect(accounts, isEmpty);
    });
  });

  group('18-21. Mock transaction content', () {
    late AccountAggregatorSyncResult result;

    setUp(() async {
      final provider = _provider();
      final connection = await _createAndApprove(provider);
      result = await provider.syncFinancialData(connectionId: connection.connectionId);
    });

    test('18. transactions include income (Salary, credit)', () {
      final salary = result.transactionsByAccountId['MOCK-ACC-HDFC-SAVINGS']!
          .where((t) => t.narration == 'Salary');
      expect(salary, isNotEmpty);
      expect(salary.every((t) => t.direction == AccountAggregatorTransactionDirection.credit), isTrue);
      expect(salary.every((t) => t.amount == 72000), isTrue);
    });

    test('19. transactions include expenses (Rent, debit)', () {
      final rent = result.transactionsByAccountId['MOCK-ACC-HDFC-SAVINGS']!
          .where((t) => t.narration == 'Rent');
      expect(rent, isNotEmpty);
      expect(rent.every((t) => t.direction == AccountAggregatorTransactionDirection.debit), isTrue);
    });

    test('20. transactions include a Loan EMI', () {
      final emi = result.transactionsByAccountId['MOCK-ACC-ICICI-PERSONALLOAN']!
          .where((t) => t.narration == 'Loan EMI');
      expect(emi, isNotEmpty);
      expect(emi.every((t) => t.amount == 14500), isTrue);
    });

    test('21. transaction references are deterministic, not random UUIDs', () {
      final salary = result.transactionsByAccountId['MOCK-ACC-HDFC-SAVINGS']!
          .firstWhere((t) => t.narration == 'Salary');
      expect(salary.referenceNumber, startsWith('MOCK-HDFC-'));
    });

    test('transactions span multiple accounts and multiple institutions', () {
      expect(result.transactionsByAccountId.keys, contains('MOCK-ACC-HDFC-SAVINGS'));
      expect(result.transactionsByAccountId.keys, contains('MOCK-ACC-ICICI-SAVINGS'));
      expect(result.transactionsByAccountId.keys, contains('MOCK-ACC-ICICI-PERSONALLOAN'));
    });

    test('includes a genuine same-day, same-merchant, different-amount pair', () {
      final swiggy = result.transactionsByAccountId['MOCK-ACC-HDFC-SAVINGS']!
          .where((t) => t.narration == 'Swiggy')
          .toList();
      expect(swiggy.length, 2);
      expect(swiggy[0].transactionDate, swiggy[1].transactionDate);
      expect(swiggy[0].amount, isNot(swiggy[1].amount));
      expect(swiggy[0].id, isNot(swiggy[1].id));
    });
  });

  group('22-24, 27. Partial / empty / malformed simulations', () {
    test('22. empty transaction history is a valid, non-partial result', () async {
      final provider = _provider(failureMode: MockAccountAggregatorFailureMode.emptyTransactionHistory);
      final connection = await _createAndApprove(provider);
      final result = await provider.syncFinancialData(connectionId: connection.connectionId);
      expect(result.totalTransactionCount, 0);
      expect(result.isPartial, isFalse);
      expect(result.errorMessage, isNull);
      expect(result.accounts, isNotEmpty); // accounts still discovered normally
    });

    test('23. partial account response drops accounts and flags isPartial', () async {
      final provider = _provider(failureMode: MockAccountAggregatorFailureMode.partialAccountResponse);
      final connection = await _createAndApprove(provider);
      final fullProvider = _provider();
      final fullConnection = await _createAndApprove(fullProvider);
      final fullResult = await fullProvider.syncFinancialData(connectionId: fullConnection.connectionId);

      final result = await provider.syncFinancialData(connectionId: connection.connectionId);
      expect(result.accounts.length, fullResult.accounts.length - 1);
      expect(result.isPartial, isTrue);
      expect(result.warnings, isNotEmpty);
    });

    test('24. partial transaction response returns fewer transactions and flags isPartial', () async {
      final provider = _provider(failureMode: MockAccountAggregatorFailureMode.partialTransactionResponse);
      final connection = await _createAndApprove(provider);
      final result = await provider.syncFinancialData(connectionId: connection.connectionId);

      final fullProvider = _provider();
      final fullConnection = await _createAndApprove(fullProvider);
      final fullResult = await fullProvider.syncFinancialData(connectionId: fullConnection.connectionId);

      expect(result.totalTransactionCount, lessThan(fullResult.totalTransactionCount));
      expect(result.isPartial, isTrue);
    });

    test('27. malformed transaction data is flagged, never silently accepted as valid', () async {
      final provider = _provider(failureMode: MockAccountAggregatorFailureMode.malformedTransactionData);
      final connection = await _createAndApprove(provider);
      final result = await provider.syncFinancialData(connectionId: connection.connectionId);
      expect(result.isPartial, isTrue);
      expect(result.warnings, isNotEmpty);
    });

    test('partial/malformed modes never fabricate records to make counts look complete', () async {
      final provider = _provider(failureMode: MockAccountAggregatorFailureMode.partialAccountResponse);
      final connection = await _createAndApprove(provider);
      final result = await provider.syncFinancialData(connectionId: connection.connectionId);
      final fullCatalogSize = 4;
      expect(result.accounts.length, lessThan(fullCatalogSize));
    });
  });

  group('25-26. Provider-level failures', () {
    test('25. providerUnavailable failure is raised, never silently converted to success', () async {
      final provider = _provider(failureMode: MockAccountAggregatorFailureMode.providerUnavailable);
      expect(
        () => provider.createConsent(
          userId: _userId,
          institutionTypes: _allTypes,
          historyDuration: const Duration(days: 180),
        ),
        throwsA(
          isA<AccountAggregatorException>().having(
            (e) => e.code,
            'code',
            AccountAggregatorErrorCode.providerUnavailable,
          ),
        ),
      );
    });

    test('26. networkTimeout failure is raised, never silently converted to success', () async {
      final provider = _provider(failureMode: MockAccountAggregatorFailureMode.networkTimeout);
      expect(
        () => provider.createConsent(
          userId: _userId,
          institutionTypes: _allTypes,
          historyDuration: const Duration(days: 180),
        ),
        throwsA(
          isA<AccountAggregatorException>().having(
            (e) => e.code,
            'code',
            AccountAggregatorErrorCode.networkTimeout,
          ),
        ),
      );
    });

    test('consentRejected failure mode reports rejection at consent-creation time', () async {
      final provider = _provider(failureMode: MockAccountAggregatorFailureMode.consentRejected);
      final connection = await provider.createConsent(
        userId: _userId,
        institutionTypes: _allTypes,
        historyDuration: const Duration(days: 180),
      );
      expect(connection.consentStatus, ConsentStatus.rejected);
    });
  });

  group('28-29. Revoked/expired consent blocks data access', () {
    test('28. revoked consent blocks account/transaction access', () async {
      final provider = _provider();
      final connection = await _createAndApprove(provider);
      await provider.revokeConsent(connectionId: connection.connectionId);

      expect(
        () => provider.fetchAccounts(connectionId: connection.connectionId),
        throwsA(isA<AccountAggregatorException>()),
      );
      expect(
        () => provider.syncFinancialData(connectionId: connection.connectionId),
        throwsA(isA<AccountAggregatorException>()),
      );
    });

    test('29. expired consent blocks account/transaction access', () async {
      final provider = _provider();
      final connection = await _createAndApprove(provider);
      provider.expireConsent(connection.connectionId);

      expect(
        () => provider.fetchAccounts(connectionId: connection.connectionId),
        throwsA(isA<AccountAggregatorException>()),
      );
      expect(
        () => provider.syncFinancialData(connectionId: connection.connectionId),
        throwsA(isA<AccountAggregatorException>()),
      );
    });
  });

  group('32. Reference-date determinism', () {
    test('the same referenceDate always produces the same transaction dates', () async {
      final providerA = _provider();
      final connectionA = await _createAndApprove(providerA);
      final resultA = await providerA.syncFinancialData(connectionId: connectionA.connectionId);

      final providerB = MockAccountAggregatorProvider(referenceDate: _referenceDate);
      final connectionB = await _createAndApprove(providerB);
      final resultB = await providerB.syncFinancialData(connectionId: connectionB.connectionId);

      final salaryA = resultA.transactionsByAccountId['MOCK-ACC-HDFC-SAVINGS']!
          .firstWhere((t) => t.narration == 'Salary' && t.id == 'MOCK-HDFC-000003');
      final salaryB = resultB.transactionsByAccountId['MOCK-ACC-HDFC-SAVINGS']!
          .firstWhere((t) => t.narration == 'Salary' && t.id == 'MOCK-HDFC-000003');
      expect(salaryA.transactionDate, salaryB.transactionDate);
      expect(salaryA.transactionDate, DateTime(2026, 8, 1));
    });

    test('a different referenceDate shifts the deterministic transaction dates accordingly', () async {
      final provider = MockAccountAggregatorProvider(referenceDate: DateTime(2027, 1, 15));
      final connection = await _createAndApprove(provider);
      final result = await provider.syncFinancialData(connectionId: connection.connectionId);
      final latestSalary = result.transactionsByAccountId['MOCK-ACC-HDFC-SAVINGS']!
          .firstWhere((t) => t.id == 'MOCK-HDFC-000003');
      expect(latestSalary.transactionDate, DateTime(2027, 1, 1));
    });
  });

  group('Service integration (AccountAggregatorService -> AccountAggregatorProvider)', () {
    test('AccountAggregatorService forwards calls to the injected provider unchanged', () async {
      final mock = _provider();
      final service = AccountAggregatorService(mock);

      expect(service.activeProviderId, 'mock');

      final connection = await service.createConsent(
        userId: _userId,
        institutionTypes: _allTypes,
        historyDuration: const Duration(days: 180),
      );
      expect(connection.status, ConnectionStatus.awaitingConsent);

      final polled = await service.getConsentStatus(connectionId: connection.connectionId);
      expect(polled.connectionId, connection.connectionId);
    });
  });

  group('Dev-control misuse safety', () {
    test('approving an already-approved consent throws, rather than silently succeeding', () async {
      final provider = _provider();
      final connection = await _createAndApprove(provider);
      expect(() => provider.approveConsent(connection.connectionId), throwsStateError);
    });

    test('rejecting a non-pending consent throws', () async {
      final provider = _provider();
      final connection = await _createAndApprove(provider);
      expect(() => provider.rejectConsent(connection.connectionId), throwsStateError);
    });
  });
}
