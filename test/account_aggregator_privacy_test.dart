// ACCOUNT AGGREGATOR / ONE-TAP CONNECT — PHASE 3. Recursive privacy tests,
// following the same convention already established in
// test/transaction_ingestion_privacy_test.dart (Phase 1) and
// test/csv_import_persistence_test.dart's analytics check (CSV Phase 2):
// the mock provider's models, serialization, and behavior must never
// carry a password/PIN/OTP/CVV/card-number/credential/SMS/phone fragment.
import 'package:flutter_test/flutter_test.dart';
import 'package:paysense/shared/services/account_aggregator/account_aggregator_models.dart';
import 'package:paysense/shared/services/account_aggregator/mock_account_aggregator_provider.dart';
import 'package:paysense/shared/services/analytics_service.dart';

const _forbiddenFragments = [
  'password',
  'passwd',
  'pin',
  'upipin',
  'otp',
  'cvv',
  'cardnumber',
  'secret',
  'token',
  'credential',
  'smsbody',
  'sms',
  'phone',
];

String _normalize(String raw) => raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

/// Recursively walks a JSON-shaped value (the output of `toMap()`) and
/// asserts no forbidden fragment appears in any KEY or any STRING VALUE.
///
/// "transaction"/"description"/"account" — normal, safe financial
/// vocabulary this codebase uses everywhere — contain none of
/// [_forbiddenFragments] as a substring, so no special-case skip is
/// needed to avoid a false positive; keeping the check uniform for every
/// key and value matches this codebase's existing privacy-test
/// convention (Phase 1's `transaction_ingestion_privacy_test.dart`) most
/// closely.
void _assertNoForbiddenFragment(dynamic value, {String path = r'$'}) {
  if (value is Map) {
    value.forEach((key, v) {
      final normalizedKey = _normalize(key.toString());
      for (final fragment in _forbiddenFragments) {
        expect(
          normalizedKey.contains(fragment),
          isFalse,
          reason: 'Forbidden fragment "$fragment" found in key "$key" at $path',
        );
      }
      _assertNoForbiddenFragment(v, path: '$path.$key');
    });
    return;
  }
  if (value is List) {
    for (var i = 0; i < value.length; i++) {
      _assertNoForbiddenFragment(value[i], path: '$path[$i]');
    }
    return;
  }
  if (value is String) {
    final normalized = _normalize(value);
    for (final fragment in _forbiddenFragments) {
      expect(
        normalized.contains(fragment),
        isFalse,
        reason: 'Forbidden fragment "$fragment" found in value "$value" at $path',
      );
    }
  }
}

void main() {
  final referenceDate = DateTime(2026, 8, 26);
  const userId = 'privacy-test-user';
  const types = [
    FinancialInstitutionType.bank,
    FinancialInstitutionType.creditCard,
    FinancialInstitutionType.loan,
  ];

  group('30. Structural privacy — models have no field for a forbidden concept', () {
    test('AccountAggregatorAccount has no credential-shaped field', () {
      const account = AccountAggregatorAccount(
        id: 'id',
        displayName: 'name',
        institutionName: 'bank',
        institutionType: FinancialInstitutionType.bank,
        maskedIdentifier: '•••• 1234',
      );
      _assertNoForbiddenFragment(account.toMap());
    });

    test('AccountAggregatorTransaction has no credential-shaped field', () {
      final transaction = AccountAggregatorTransaction(
        id: 'id',
        accountId: 'acc',
        amount: 100,
        direction: AccountAggregatorTransactionDirection.debit,
        transactionDate: referenceDate,
        narration: 'Coffee Shop',
        mode: 'UPI',
      );
      _assertNoForbiddenFragment(transaction.toMap());
    });

    test('AccountAggregatorConnection (with nested accounts) has no credential-shaped field', () {
      final connection = AccountAggregatorConnection(
        connectionId: 'conn-1',
        providerId: 'mock',
        providerName: 'Sandbox / Mock Provider',
        status: ConnectionStatus.connected,
        consentStatus: ConsentStatus.approved,
        createdAt: referenceDate,
        updatedAt: referenceDate,
        accounts: const [
          AccountAggregatorAccount(
            id: 'id',
            displayName: 'name',
            institutionName: 'bank',
            institutionType: FinancialInstitutionType.bank,
            maskedIdentifier: '•••• 1234',
          ),
        ],
      );
      _assertNoForbiddenFragment(connection.toMap());
    });

    test('AccountAggregatorException message never contains a forbidden fragment', () {
      const exception = AccountAggregatorException(
        AccountAggregatorErrorCode.providerUnavailable,
        'Your bank connection is temporarily unavailable. Your existing PaySense data is safe.',
      );
      _assertNoForbiddenFragment(exception.message);
      _assertNoForbiddenFragment(exception.toString());
    });
  });

  group('30b. End-to-end mock provider run — recursive scan of every produced object', () {
    test('a full consent + sync cycle never surfaces a forbidden fragment anywhere', () async {
      final provider = MockAccountAggregatorProvider(referenceDate: referenceDate);
      final connection = await provider.createConsent(
        userId: userId,
        institutionTypes: types,
        historyDuration: const Duration(days: 180),
      );
      _assertNoForbiddenFragment(connection.toMap());

      final approved = provider.approveConsent(connection.connectionId);
      _assertNoForbiddenFragment(approved.toMap());

      final accounts = await provider.fetchAccounts(connectionId: connection.connectionId);
      for (final account in accounts) {
        _assertNoForbiddenFragment(account.toMap());
      }

      final syncResult = await provider.syncFinancialData(connectionId: connection.connectionId);
      for (final account in syncResult.accounts) {
        _assertNoForbiddenFragment(account.toMap());
      }
      for (final transactions in syncResult.transactionsByAccountId.values) {
        for (final transaction in transactions) {
          _assertNoForbiddenFragment(transaction.toMap());
        }
      }
      _assertNoForbiddenFragment(syncResult.warnings);

      final revoked = await provider.revokeConsent(connectionId: connection.connectionId);
      _assertNoForbiddenFragment(revoked.toMap());
    });

    test('maskedIdentifier is always masked, never a full account/card number', () async {
      final provider = MockAccountAggregatorProvider(referenceDate: referenceDate);
      final connection = await provider.createConsent(
        userId: userId,
        institutionTypes: types,
        historyDuration: const Duration(days: 180),
      );
      provider.approveConsent(connection.connectionId);
      final accounts = await provider.fetchAccounts(connectionId: connection.connectionId);
      for (final account in accounts) {
        expect(account.maskedIdentifier, contains('••••'));
        // A real 16-digit card / account number must never appear.
        expect(RegExp(r'\d{9,}').hasMatch(account.maskedIdentifier), isFalse);
      }
    });
  });

  group('31. No sensitive logging', () {
    test('a full mock provider lifecycle never logs anything through AnalyticsService', () async {
      final before = AnalyticsService.instance.debugLog.length;

      final provider = MockAccountAggregatorProvider(referenceDate: referenceDate);
      final connection = await provider.createConsent(
        userId: userId,
        institutionTypes: types,
        historyDuration: const Duration(days: 180),
      );
      provider.approveConsent(connection.connectionId);
      await provider.fetchAccounts(connectionId: connection.connectionId);
      await provider.syncFinancialData(connectionId: connection.connectionId);
      await provider.revokeConsent(connectionId: connection.connectionId);

      expect(AnalyticsService.instance.debugLog.length, before);
    });
  });

  group('Safe-word guard — the scanner itself must not false-positive', () {
    test('"transaction", "description", and "account" never trip the forbidden-fragment scan', () {
      expect(() => _assertNoForbiddenFragment({'description': 'A normal transaction on this account'}), returnsNormally);
    });
  });
}
