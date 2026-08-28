import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/account_aggregator_connection_repository.dart';
import '../services/account_aggregator/account_aggregator_models.dart';
import '../services/account_aggregator/account_aggregator_sync_service.dart';
import 'account_aggregator_provider.dart';

/// ACCOUNT AGGREGATOR — PART A. The PERSISTED, settled list of
/// [AccountAggregatorConnection]s — what the Settings "Connected
/// Financial Accounts" screen, the Connected Accounts screen, and the
/// Dashboard's compact status entry all read from. Distinct from
/// `BankConnectNotifier` (the one-time, in-progress "Connect Bank"
/// wizard) exactly the way `TransactionsNotifier` is distinct from
/// `CsvImportNotifier` — one is the settled state, the other is a
/// transient flow that eventually writes into it.
final accountAggregatorConnectionsProvider =
    AsyncNotifierProvider<AccountAggregatorConnectionsNotifier, List<AccountAggregatorConnection>>(
  AccountAggregatorConnectionsNotifier.new,
);

class AccountAggregatorConnectionsNotifier extends AsyncNotifier<List<AccountAggregatorConnection>> {
  @override
  Future<List<AccountAggregatorConnection>> build() {
    return AccountAggregatorConnectionRepository.instance.getAll();
  }

  Future<void> reload() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => AccountAggregatorConnectionRepository.instance.getAll());
  }

  /// PART E — "Sync Now". Re-runs ingestion for every bank/deposit
  /// account already mapped to a wallet on this connection; liability
  /// accounts and any still-unmapped account are skipped, exactly as the
  /// initial connect flow does (see `AccountAggregatorSyncService`).
  Future<AaSyncSummary> syncNow(String connectionId) async {
    final connection = await AccountAggregatorConnectionRepository.instance.getById(connectionId);
    if (connection == null) {
      throw StateError('syncNow: no connection found for id "$connectionId".');
    }

    final walletIdByAaAccountId = <String, String>{
      for (final account in connection.accounts)
        if (account.linkedWalletId != null) account.id: account.linkedWalletId!,
    };

    final summary = await AccountAggregatorSyncService.syncAndIngest(
      service: ref.read(accountAggregatorServiceProvider),
      connectionId: connectionId,
      walletIdByAaAccountId: walletIdByAaAccountId,
      since: connection.lastSyncedAt,
    );

    final updatedConnection = connection.copyWith(
      accounts: summary.syncResult.accounts.map((refreshed) {
        // Preserve each account's existing wallet mapping — the sync
        // result only refreshes balance/lastSyncedAt/status, it never
        // knows about wallet mappings (PART D lives above this layer).
        final existing = connection.accounts.firstWhere(
          (a) => a.id == refreshed.id,
          orElse: () => refreshed,
        );
        return refreshed.copyWith(linkedWalletId: existing.linkedWalletId);
      }).toList(),
      lastSyncedAt: summary.syncResult.syncedAt,
    );
    await AccountAggregatorConnectionRepository.instance.upsert(updatedConnection);

    await reload();
    return summary;
  }

  /// PART A — revoke consent for a connection. Per PHASE 15's rule,
  /// historical transactions already ingested are NEVER deleted here —
  /// only the connection's own consent/status metadata changes.
  Future<void> revoke(String connectionId) async {
    final updated = await ref.read(accountAggregatorServiceProvider).revokeConsent(connectionId: connectionId);
    await AccountAggregatorConnectionRepository.instance.upsert(updated);
    await reload();
  }

  /// A full "Disconnect" — removes the connection record itself (still
  /// never touches historical `Transaction`s, matching `revoke`).
  Future<void> disconnect(String connectionId) async {
    await AccountAggregatorConnectionRepository.instance.delete(connectionId);
    await reload();
  }
}
