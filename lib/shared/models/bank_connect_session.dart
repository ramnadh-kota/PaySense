import 'package:flutter/foundation.dart';

import '../services/account_aggregator/account_aggregator_models.dart';
import '../services/account_aggregator/account_aggregator_sync_service.dart';

/// ACCOUNT AGGREGATOR — PART A/B. The in-progress "Connect Bank" wizard's
/// single source of truth, mirroring the proven `CsvImportSession` /
/// `CsvImportNotifier` shape from the CSV import feature: an immutable
/// session object plus a `Notifier` that produces new copies of it. Never
/// persisted to Hive — this only exists for the duration of one connect
/// flow; once it reaches [BankConnectStep.completed], the resulting
/// [AccountAggregatorConnection] is what gets persisted (via
/// `AccountAggregatorConnectionRepository`), not this session itself.
enum BankConnectStep {
  selectingInstitutions,
  consentExplanation,
  awaitingConsent,
  fetchingAccounts,
  mappingAccounts,
  syncing,
  completed,
  failed,
}

/// What the user has decided to do with ONE discovered AA account during
/// PART D's mapping step. `pending` (the default) means "not decided
/// yet" — an account left `pending` is never ingested, matching the
/// existing ingestion pipeline's own "never guess" discipline.
enum AccountMappingDecision { pending, createNewWallet, mapToExistingWallet, ignore }

@immutable
class BankConnectSession {
  const BankConnectSession({
    this.step = BankConnectStep.selectingInstitutions,
    this.selectedInstitutionTypes = const [],
    this.historyDuration = const Duration(days: 180),
    this.connection,
    this.mappingDecisions = const {},
    this.selectedWalletIdByAccountId = const {},
    this.newWalletNameByAccountId = const {},
    this.syncSummary,
    this.errorMessage,
  });

  final BankConnectStep step;
  final List<FinancialInstitutionType> selectedInstitutionTypes;

  /// PHASE 9's "3/6/12 months" choice — default 6 months, never more
  /// history than the user actually picked.
  final Duration historyDuration;

  /// The connection this session is building — null until
  /// `createConsent` has actually been called.
  final AccountAggregatorConnection? connection;

  /// Keyed by [AccountAggregatorAccount.id]. Only bank/deposit accounts
  /// are ever offered a real mapping decision (PART D) — liability
  /// accounts (credit card/loan) are always informational-only and never
  /// appear here.
  final Map<String, AccountMappingDecision> mappingDecisions;

  /// For [AccountMappingDecision.mapToExistingWallet] — the chosen real
  /// `Wallet.id`.
  final Map<String, String> selectedWalletIdByAccountId;

  /// For [AccountMappingDecision.createNewWallet] — the name the user
  /// wants for the brand-new wallet (defaults to the AA account's own
  /// display name if never overridden, applied by the notifier, not
  /// stored blank here).
  final Map<String, String> newWalletNameByAccountId;

  final AaSyncSummary? syncSummary;
  final String? errorMessage;

  List<AccountAggregatorAccount> get discoveredAccounts => connection?.accounts ?? const [];

  /// Bank/deposit accounts only — the only ones PART D ever offers a
  /// wallet-mapping action for.
  List<AccountAggregatorAccount> get mappableAccounts => discoveredAccounts
      .where((a) => a.institutionType == FinancialInstitutionType.bank || a.institutionType == FinancialInstitutionType.deposit)
      .toList();

  /// Liability accounts (credit card/loan) — shown for reference only,
  /// per PART D's explicit rule: never mapped to a cash wallet.
  List<AccountAggregatorAccount> get liabilityAccounts =>
      discoveredAccounts.where((a) => a.institutionType.isLiability).toList();

  bool get allMappableAccountsDecided =>
      mappableAccounts.isNotEmpty &&
      mappableAccounts.every((a) => (mappingDecisions[a.id] ?? AccountMappingDecision.pending) != AccountMappingDecision.pending);

  BankConnectSession copyWith({
    BankConnectStep? step,
    List<FinancialInstitutionType>? selectedInstitutionTypes,
    Duration? historyDuration,
    AccountAggregatorConnection? connection,
    Map<String, AccountMappingDecision>? mappingDecisions,
    Map<String, String>? selectedWalletIdByAccountId,
    Map<String, String>? newWalletNameByAccountId,
    AaSyncSummary? syncSummary,
    String? errorMessage,
    bool clearError = false,
  }) {
    return BankConnectSession(
      step: step ?? this.step,
      selectedInstitutionTypes: selectedInstitutionTypes ?? this.selectedInstitutionTypes,
      historyDuration: historyDuration ?? this.historyDuration,
      connection: connection ?? this.connection,
      mappingDecisions: mappingDecisions ?? this.mappingDecisions,
      selectedWalletIdByAccountId: selectedWalletIdByAccountId ?? this.selectedWalletIdByAccountId,
      newWalletNameByAccountId: newWalletNameByAccountId ?? this.newWalletNameByAccountId,
      syncSummary: syncSummary ?? this.syncSummary,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
