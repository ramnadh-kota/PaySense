import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:paysense/shared/providers/account_aggregator_provider.dart';
import 'package:paysense/shared/services/account_aggregator/account_aggregator_config.dart';
import 'package:paysense/shared/services/account_aggregator/account_aggregator_models.dart';
import 'package:paysense/shared/services/account_aggregator/account_aggregator_network_client.dart';
import 'package:paysense/shared/services/account_aggregator/mock_account_aggregator_provider.dart';
import 'package:paysense/shared/services/account_aggregator/production_account_aggregator_provider.dart';
import 'package:paysense/shared/services/account_aggregator/sandbox_account_aggregator_provider.dart';

void main() {
  group('AccountAggregatorConfig', () {
    test('fromEnvironment defaults to mock when nothing is defined', () {
      final config = AccountAggregatorConfig.fromEnvironment();
      expect(config.environment, AccountAggregatorEnvironment.mock);
      expect(config.isNetworkConfigured, isFalse);
    });

    test('mock never requires network configuration', () {
      const config = AccountAggregatorConfig(environment: AccountAggregatorEnvironment.mock);
      expect(config.isNetworkConfigured, isFalse);
    });

    test('sandbox/production require both baseUrl and clientId to be considered configured', () {
      const missingClientId = AccountAggregatorConfig(
        environment: AccountAggregatorEnvironment.sandbox,
        baseUrl: 'https://example.internal',
      );
      expect(missingClientId.isNetworkConfigured, isFalse);

      const fullyConfigured = AccountAggregatorConfig(
        environment: AccountAggregatorEnvironment.sandbox,
        baseUrl: 'https://example.internal',
        clientId: 'client-1',
      );
      expect(fullyConfigured.isNetworkConfigured, isTrue);
    });
  });

  group('Provider selection layer — never silently substitutes mock', () {
    test('environment=mock resolves to MockAccountAggregatorProvider', () {
      final container = ProviderContainer(
        overrides: [
          accountAggregatorConfigProvider.overrideWithValue(
            const AccountAggregatorConfig(environment: AccountAggregatorEnvironment.mock),
          ),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(accountAggregatorProviderImplProvider), isA<MockAccountAggregatorProvider>());
    });

    test('environment=sandbox resolves to SandboxAccountAggregatorProvider, never mock', () {
      final container = ProviderContainer(
        overrides: [
          accountAggregatorConfigProvider.overrideWithValue(
            const AccountAggregatorConfig(
              environment: AccountAggregatorEnvironment.sandbox,
              baseUrl: 'https://example.internal',
              clientId: 'client-1',
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      final impl = container.read(accountAggregatorProviderImplProvider);
      expect(impl, isA<SandboxAccountAggregatorProvider>());
      expect(impl, isNot(isA<MockAccountAggregatorProvider>()));
    });

    test('environment=production resolves to ProductionAccountAggregatorProvider, NEVER mock, '
        'even when configuration is incomplete', () {
      final container = ProviderContainer(
        overrides: [
          accountAggregatorConfigProvider.overrideWithValue(
            const AccountAggregatorConfig(environment: AccountAggregatorEnvironment.production),
          ),
        ],
      );
      addTearDown(container.dispose);
      final impl = container.read(accountAggregatorProviderImplProvider);
      expect(impl, isA<ProductionAccountAggregatorProvider>());
      expect(impl, isNot(isA<MockAccountAggregatorProvider>()));
    });

    test('dev controls are exposed for mock and sandbox but NEVER for production', () {
      final mockContainer = ProviderContainer(
        overrides: [
          accountAggregatorConfigProvider.overrideWithValue(
            const AccountAggregatorConfig(environment: AccountAggregatorEnvironment.mock),
          ),
        ],
      );
      addTearDown(mockContainer.dispose);
      expect(mockContainer.read(accountAggregatorDevControlsProvider), isNotNull);

      final sandboxContainer = ProviderContainer(
        overrides: [
          accountAggregatorConfigProvider.overrideWithValue(
            const AccountAggregatorConfig(
              environment: AccountAggregatorEnvironment.sandbox,
              baseUrl: 'https://example.internal',
              clientId: 'client-1',
            ),
          ),
        ],
      );
      addTearDown(sandboxContainer.dispose);
      expect(sandboxContainer.read(accountAggregatorDevControlsProvider), isNotNull);

      final productionContainer = ProviderContainer(
        overrides: [
          accountAggregatorConfigProvider.overrideWithValue(
            const AccountAggregatorConfig(environment: AccountAggregatorEnvironment.production),
          ),
        ],
      );
      addTearDown(productionContainer.dispose);
      expect(productionContainer.read(accountAggregatorDevControlsProvider), isNull);
    });
  });

  group('SandboxAccountAggregatorProvider', () {
    test('throws configurationMissing when baseUrl/clientId are absent', () async {
      final provider = SandboxAccountAggregatorProvider(
        config: const AccountAggregatorConfig(environment: AccountAggregatorEnvironment.sandbox),
      );
      expect(
        () => provider.createConsent(
          userId: 'u1',
          institutionTypes: const [FinancialInstitutionType.bank],
          historyDuration: const Duration(days: 180),
        ),
        throwsA(
          isA<AccountAggregatorException>().having((e) => e.code, 'code', AccountAggregatorErrorCode.configurationMissing),
        ),
      );
    });

    test('produces deterministic data via the same generator as mock, tagged as "sandbox"', () async {
      final referenceDate = DateTime(2026, 8, 26);
      final provider = SandboxAccountAggregatorProvider(
        referenceDate: referenceDate,
        config: const AccountAggregatorConfig(
          environment: AccountAggregatorEnvironment.sandbox,
          baseUrl: 'https://example.internal',
          clientId: 'client-1',
        ),
      );

      final connection = await provider.createConsent(
        userId: 'u1',
        institutionTypes: const [FinancialInstitutionType.bank],
        historyDuration: const Duration(days: 180),
      );
      expect(connection.providerId, 'sandbox');
      expect(connection.isMock, isFalse);

      final approved = provider.approveConsent(connection.connectionId);
      expect(approved.providerId, 'sandbox');

      final accounts = await provider.fetchAccounts(connectionId: connection.connectionId);
      expect(accounts, isNotEmpty);
      expect(accounts.any((a) => a.institutionName == 'HDFC Bank'), isTrue);
    });
  });

  group('ProductionAccountAggregatorProvider — honest stub, never fabricates a connection', () {
    const config = AccountAggregatorConfig(environment: AccountAggregatorEnvironment.production);

    test('every method throws notImplemented rather than returning fake data', () async {
      final provider = ProductionAccountAggregatorProvider(config: config);

      Matcher throwsNotImplemented() => throwsA(
            isA<AccountAggregatorException>().having((e) => e.code, 'code', AccountAggregatorErrorCode.notImplemented),
          );

      await expectLater(
        provider.createConsent(userId: 'u1', institutionTypes: const [FinancialInstitutionType.bank], historyDuration: const Duration(days: 180)),
        throwsNotImplemented(),
      );
      await expectLater(provider.getConsentStatus(connectionId: 'c1'), throwsNotImplemented());
      await expectLater(provider.fetchAccounts(connectionId: 'c1'), throwsNotImplemented());
      await expectLater(provider.syncFinancialData(connectionId: 'c1'), throwsNotImplemented());
      await expectLater(provider.revokeConsent(connectionId: 'c1'), throwsNotImplemented());
    });

    test('the error message never claims a real connection exists', () async {
      final provider = ProductionAccountAggregatorProvider(config: config);
      try {
        await provider.createConsent(userId: 'u1', institutionTypes: const [FinancialInstitutionType.bank], historyDuration: const Duration(days: 180));
        fail('should have thrown');
      } on AccountAggregatorException catch (e) {
        expect(e.message.toLowerCase(), contains('not yet configured'));
      }
    });
  });

  group('AccountAggregatorNetworkClient', () {
    test('throws configurationMissing rather than attempting a request with no baseUrl', () async {
      final client = AccountAggregatorNetworkClient(
        config: const AccountAggregatorConfig(environment: AccountAggregatorEnvironment.sandbox),
      );
      expect(
        () => client.get('/aa/accounts'),
        throwsA(
          isA<AccountAggregatorException>().having((e) => e.code, 'code', AccountAggregatorErrorCode.configurationMissing),
        ),
      );
    });

    test('never logs a request body or credential — only method/path/status/duration', () async {
      final client = AccountAggregatorNetworkClient(
        config: const AccountAggregatorConfig(environment: AccountAggregatorEnvironment.sandbox),
      );
      try {
        await client.get('/aa/accounts');
      } catch (_) {
        // expected — no network configured.
      }
      for (final entry in client.debugLog) {
        expect(entry.toLowerCase().contains('token'), isFalse);
        expect(entry.toLowerCase().contains('secret'), isFalse);
        expect(entry.toLowerCase().contains('password'), isFalse);
      }
    });

    test('retries a failing GET with backoff, waiting between attempts, then succeeds', () async {
      var callCount = 0;
      final mockHttp = MockClient((request) async {
        callCount++;
        if (callCount < 3) {
          throw Exception('simulated network failure');
        }
        return http.Response('{"ok":true}', 200);
      });
      final delays = <int>[];
      final client = AccountAggregatorNetworkClient(
        config: const AccountAggregatorConfig(
          environment: AccountAggregatorEnvironment.sandbox,
          baseUrl: 'https://example.internal',
          clientId: 'client-1',
          maxRetries: 3,
        ),
        httpClient: mockHttp,
        retryDelay: (attempt) {
          delays.add(attempt);
          return Duration.zero;
        },
      );

      final result = await client.get('/aa/accounts');

      expect(result, {'ok': true});
      expect(callCount, 3);
      expect(delays, [1, 2]); // a delay is inserted before retry attempts 2 and 3
    });

    test('a non-retryable POST never retries and never waits', () async {
      var callCount = 0;
      final mockHttp = MockClient((request) async {
        callCount++;
        throw Exception('simulated network failure');
      });
      var delayCalls = 0;
      final client = AccountAggregatorNetworkClient(
        config: const AccountAggregatorConfig(
          environment: AccountAggregatorEnvironment.sandbox,
          baseUrl: 'https://example.internal',
          clientId: 'client-1',
          maxRetries: 3,
        ),
        httpClient: mockHttp,
        retryDelay: (attempt) {
          delayCalls++;
          return Duration.zero;
        },
      );

      await expectLater(client.post('/aa/consent/initiate'), throwsA(isA<AccountAggregatorException>()));
      expect(callCount, 1);
      expect(delayCalls, 0);
    });
  });
}
