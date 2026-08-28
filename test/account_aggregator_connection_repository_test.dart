// BUG REGRESSION: the Dashboard threw
// "type '_Map<dynamic, dynamic>' is not a subtype of type
// 'Map<String, dynamic>' in type cast" whenever a real AccountAggregator
// connection with at least one discovered account existed. Root cause:
// AccountAggregatorConnection.fromMap did `a as Map<String, dynamic>` on
// each element of the nested `accounts` list — Hive deserializes a
// NESTED map (inside a List, inside another Map) as a raw
// `Map<dynamic, dynamic>`, not the exact generic type it was written
// with, so the direct cast threw. This can only be reproduced through a
// REAL Hive binary write -> read round trip (an in-memory toMap/fromMap
// call would never hit it, since Dart's own map literal keeps its
// declared generic type).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:paysense/shared/repositories/account_aggregator_connection_repository.dart';
import 'package:paysense/shared/services/account_aggregator/account_aggregator_models.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('paysense_aa_connection_repo_test');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('AccountAggregatorConnectionRepository — real Hive round trip', () {
    test('a connection with one linked account survives a real write/read cycle without a cast error', () async {
      final connection = AccountAggregatorConnection(
        connectionId: 'conn-1',
        providerId: 'mock',
        providerName: 'Mock Provider',
        status: ConnectionStatus.connected,
        consentStatus: ConsentStatus.approved,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        accounts: const [
          AccountAggregatorAccount(
            id: 'acc-1',
            displayName: 'HDFC Savings',
            institutionName: 'HDFC Bank',
            institutionType: FinancialInstitutionType.bank,
            maskedIdentifier: '•••• 1234',
            balance: 50000,
            linkedWalletId: 'w1',
          ),
        ],
      );

      await AccountAggregatorConnectionRepository.instance.upsert(connection);
      // Force a real disk round trip: an already-open Hive box serves
      // `.values`/`.get()` from its in-memory cache, which never exercises
      // the binary deserializer and would NOT reproduce the bug. Closing
      // and letting the repository's lazy `_box()` reopen it is what
      // actually forces Hive to decode the stored bytes back into
      // objects, which is where nested maps lose their exact generic type.
      await Hive.box(AccountAggregatorConnectionRepository.boxName).close();

      // getAll() is the exact call the Dashboard's _BankConnectEntryLine
      // triggers via accountAggregatorConnectionsProvider — must not throw.
      final all = await AccountAggregatorConnectionRepository.instance.getAll();

      expect(all, hasLength(1));
      expect(all.single.accounts, hasLength(1));
      expect(all.single.accounts.single.displayName, 'HDFC Savings');
      expect(all.single.accounts.single.linkedWalletId, 'w1');
    });

    test('a connection with MULTIPLE accounts round-trips correctly, none dropped or corrupted', () async {
      final connection = AccountAggregatorConnection(
        connectionId: 'conn-2',
        providerId: 'mock',
        providerName: 'Mock Provider',
        status: ConnectionStatus.partiallyConnected,
        consentStatus: ConsentStatus.approved,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 2),
        accounts: const [
          AccountAggregatorAccount(
            id: 'acc-1',
            displayName: 'HDFC Savings',
            institutionName: 'HDFC Bank',
            institutionType: FinancialInstitutionType.bank,
            maskedIdentifier: '•••• 1234',
            balance: 50000,
          ),
          AccountAggregatorAccount(
            id: 'acc-2',
            displayName: 'HDFC Credit Card',
            institutionName: 'HDFC Bank',
            institutionType: FinancialInstitutionType.creditCard,
            maskedIdentifier: '•••• 9876',
            balance: 12000,
          ),
        ],
      );

      await AccountAggregatorConnectionRepository.instance.upsert(connection);
      await Hive.box(AccountAggregatorConnectionRepository.boxName).close();
      final fetched = await AccountAggregatorConnectionRepository.instance.getById('conn-2');

      expect(fetched, isNotNull);
      expect(fetched!.accounts, hasLength(2));
      expect(fetched.accounts.map((a) => a.id), containsAll(['acc-1', 'acc-2']));
    });

    test('a connection with zero accounts (pre-discovery) round-trips without error', () async {
      final connection = AccountAggregatorConnection(
        connectionId: 'conn-3',
        providerId: 'mock',
        providerName: 'Mock Provider',
        status: ConnectionStatus.awaitingConsent,
        consentStatus: ConsentStatus.pending,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      await AccountAggregatorConnectionRepository.instance.upsert(connection);
      await Hive.box(AccountAggregatorConnectionRepository.boxName).close();
      final all = await AccountAggregatorConnectionRepository.instance.getAll();

      expect(all.single.accounts, isEmpty);
    });
  });
}
