import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/bank_connect_session.dart';
import '../models/wallet.dart';
import '../repositories/account_aggregator_connection_repository.dart';
import '../repositories/wallet_repository.dart';
import '../services/account_aggregator/account_aggregator_models.dart';
import '../services/account_aggregator/account_aggregator_sync_service.dart';
import 'account_aggregator_connections_provider.dart';
import 'account_aggregator_provider.dart';
import 'transaction_provider.dart';
import 'wallet_provider.dart';

final bankConnectProvider = NotifierProvider<BankConnectNotifier, BankConnectSession>(BankConnectNotifier.new);

/// ACCOUNT AGGREGATOR — PART A/B/D. Drives the one-time "Connect Bank"
/// wizard end to end: institution selection -> consent -> account
/// discovery -> wallet mapping -> sync -> completion. Every method here
/// is read-only with respect to `TransactionRepository` until
/// [confirmMappingAndSync] — mirroring `CsvImportNotifier`'s PHASE 13
/// import-safety discipline exactly: nothing is written until the user
/// has actually decided what to do with each discovered account.
class BankConnectNotifier extends Notifier<BankConnectSession> {
  @override
  BankConnectSession build() => const BankConnectSession();

  void reset() {
    state = const BankConnectSession();
  }

  void selectInstitutionTypes(List<FinancialInstitutionType> types) {
    state = state.copyWith(selectedInstitutionTypes: types);
  }

  void setHistoryDuration(Duration duration) {
    state = state.copyWith(historyDuration: duration);
  }

  void proceedToConsentExplanation() {
    if (state.selectedInstitutionTypes.isEmpty) {
      state = state.copyWith(errorMessage: 'Choose at least one type of account to connect.');
      return;
    }
    state = state.copyWith(step: BankConnectStep.consentExplanation, clearError: true);
  }

  /// Creates the consent request. A stable per-device identifier should
  /// be passed as [userId] — PaySense has no server-side account system
  /// (see the AA provider interface's own doc comment), so callers
  /// should supply something like the local `UserProfile.id`.
  Future<void> startConsent(String userId) async {
    state = state.copyWith(step: BankConnectStep.awaitingConsent, clearError: true);
    try {
      final connection = await ref.read(accountAggregatorServiceProvider).createConsent(
            userId: userId,
            institutionTypes: state.selectedInstitutionTypes,
            historyDuration: state.historyDuration,
          );
      state = state.copyWith(connection: connection);
      if (connection.consentStatus != ConsentStatus.pending) {
        // A pre-configured mock failure mode (or, in production, an
        // immediate rejection) already settled the outcome.
        _applyTerminalConsentOutcome(connection);
      }
    } catch (e) {
      state = state.copyWith(step: BankConnectStep.failed, errorMessage: _humanizeError(e));
    }
  }

  /// Re-polls the current connection's consent status — the ONE method
  /// that works identically for both the mock provider (once a dev
  /// control below has been used) and a real provider (once the user has
  /// completed the AA/TSP's own external consent flow).
  Future<void> refreshConsentStatus() async {
    final connectionId = state.connection?.connectionId;
    if (connectionId == null) return;
    try {
      final connection = await ref.read(accountAggregatorServiceProvider).getConsentStatus(connectionId: connectionId);
      state = state.copyWith(connection: connection);
      if (connection.consentStatus == ConsentStatus.approved) {
        await _fetchAccounts();
      } else if (connection.consentStatus != ConsentStatus.pending) {
        _applyTerminalConsentOutcome(connection);
      }
    } catch (e) {
      state = state.copyWith(step: BankConnectStep.failed, errorMessage: _humanizeError(e));
    }
  }

  /// DEV/TEST ONLY — simulates the user approving consent on the mock
  /// provider's own (non-existent, since it's mock) external flow. A
  /// no-op if the wired provider isn't the mock (see
  /// `accountAggregatorDevControlsProvider`'s doc comment) — the UI
  /// should not render this action at all in that case.
  Future<void> simulateApproveConsent() async {
    final mock = ref.read(accountAggregatorDevControlsProvider);
    final connectionId = state.connection?.connectionId;
    if (mock == null || connectionId == null) return;
    mock.approveConsent(connectionId);
    await refreshConsentStatus();
  }

  Future<void> simulateRejectConsent() async {
    final mock = ref.read(accountAggregatorDevControlsProvider);
    final connectionId = state.connection?.connectionId;
    if (mock == null || connectionId == null) return;
    mock.rejectConsent(connectionId);
    await refreshConsentStatus();
  }

  Future<void> _fetchAccounts() async {
    final connectionId = state.connection?.connectionId;
    if (connectionId == null) return;
    state = state.copyWith(step: BankConnectStep.fetchingAccounts);
    try {
      final accounts = await ref.read(accountAggregatorServiceProvider).fetchAccounts(connectionId: connectionId);
      final connection = state.connection!.copyWith(accounts: accounts);
      state = state.copyWith(connection: connection, step: BankConnectStep.mappingAccounts);
    } catch (e) {
      state = state.copyWith(step: BankConnectStep.failed, errorMessage: _humanizeError(e));
    }
  }

  void _applyTerminalConsentOutcome(AccountAggregatorConnection connection) {
    final message = switch (connection.consentStatus) {
      ConsentStatus.rejected => 'You did not approve this connection, so no accounts were added.',
      ConsentStatus.expired => 'This consent request expired. Please try connecting again.',
      ConsentStatus.revoked => 'Access was revoked before the connection could complete.',
      _ => connection.errorMessage ?? "We couldn't complete the connection.",
    };
    state = state.copyWith(step: BankConnectStep.failed, errorMessage: message);
  }

  // ---------------------------------------------------------------------
  // PART D — wallet mapping
  // ---------------------------------------------------------------------

  void setMappingDecision(String accountId, AccountMappingDecision decision) {
    final decisions = Map<String, AccountMappingDecision>.of(state.mappingDecisions)..[accountId] = decision;
    state = state.copyWith(mappingDecisions: decisions);
  }

  void setExistingWalletChoice(String accountId, String walletId) {
    final map = Map<String, String>.of(state.selectedWalletIdByAccountId)..[accountId] = walletId;
    state = state.copyWith(
      selectedWalletIdByAccountId: map,
      mappingDecisions: Map<String, AccountMappingDecision>.of(state.mappingDecisions)
        ..[accountId] = AccountMappingDecision.mapToExistingWallet,
    );
  }

  void setNewWalletName(String accountId, String name) {
    final map = Map<String, String>.of(state.newWalletNameByAccountId)..[accountId] = name;
    state = state.copyWith(newWalletNameByAccountId: map);
  }

  /// PART D/E/13 — the only method that writes anything. For each
  /// mappable (bank/deposit) account: creates a new wallet, uses the
  /// chosen existing wallet, or leaves it unmapped (`ignore`/`pending`).
  /// Then runs the existing ingestion pipeline via
  /// [AccountAggregatorSyncService] — liability accounts are never
  /// included in the wallet map passed to it, so they can never mutate a
  /// cash wallet balance (PART D's explicit safety rule).
  Future<void> confirmMappingAndSync() async {
    final connection = state.connection;
    if (connection == null) return;

    state = state.copyWith(step: BankConnectStep.syncing, clearError: true);

    try {
      final walletIdByAaAccountId = <String, String>{};
      final updatedAccounts = <AccountAggregatorAccount>[];

      for (final account in connection.accounts) {
        if (!account.institutionType.isLiability &&
            (account.institutionType == FinancialInstitutionType.bank ||
                account.institutionType == FinancialInstitutionType.deposit)) {
          final decision = state.mappingDecisions[account.id] ?? AccountMappingDecision.pending;
          switch (decision) {
            case AccountMappingDecision.createNewWallet:
              final walletId = const Uuid().v4();
              final wallet = Wallet(
                id: walletId,
                name: state.newWalletNameByAccountId[account.id]?.trim().isNotEmpty == true
                    ? state.newWalletNameByAccountId[account.id]!.trim()
                    : account.displayName,
                bankName: account.institutionName,
                type: 'bank',
                openingBalance: account.balance ?? 0,
                currentBalance: account.balance ?? 0,
                createdAt: DateTime.now(),
              );
              await WalletRepository.instance.add(wallet);
              walletIdByAaAccountId[account.id] = walletId;
              updatedAccounts.add(account.copyWith(linkedWalletId: walletId));
            case AccountMappingDecision.mapToExistingWallet:
              final walletId = state.selectedWalletIdByAccountId[account.id];
              if (walletId != null) {
                walletIdByAaAccountId[account.id] = walletId;
                updatedAccounts.add(account.copyWith(linkedWalletId: walletId));
              } else {
                updatedAccounts.add(account);
              }
            case AccountMappingDecision.ignore:
            case AccountMappingDecision.pending:
              updatedAccounts.add(account);
          }
        } else {
          // Liability accounts are always carried through unmapped —
          // shown for reference, never fed into wallet-balance ingestion.
          updatedAccounts.add(account);
        }
      }

      final connectionWithMappings = connection.copyWith(accounts: updatedAccounts);

      final summary = await AccountAggregatorSyncService.syncAndIngest(
        service: ref.read(accountAggregatorServiceProvider),
        connectionId: connection.connectionId,
        walletIdByAaAccountId: walletIdByAaAccountId,
      );

      final finalAccounts = summary.syncResult.accounts.map((refreshed) {
        final mapped = updatedAccounts.firstWhere((a) => a.id == refreshed.id, orElse: () => refreshed);
        return refreshed.copyWith(linkedWalletId: mapped.linkedWalletId);
      }).toList();

      final finalConnection = connectionWithMappings.copyWith(
        accounts: finalAccounts,
        lastSyncedAt: summary.syncResult.syncedAt,
      );

      await AccountAggregatorConnectionRepository.instance.upsert(finalConnection);

      await ref.read(walletsProvider.notifier).reload();
      await ref.read(transactionsProvider.notifier).reload();
      await ref.read(accountAggregatorConnectionsProvider.notifier).reload();

      state = state.copyWith(step: BankConnectStep.completed, connection: finalConnection, syncSummary: summary);
    } catch (e) {
      state = state.copyWith(step: BankConnectStep.failed, errorMessage: _humanizeError(e));
    }
  }

  String _humanizeError(Object e) {
    if (e is AccountAggregatorException) return e.message;
    return "We couldn't complete the connection. Your existing PaySense data is safe.";
  }
}
