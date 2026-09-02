import '../models/financial_account.dart';
import '../models/wallet.dart';
import '../repositories/financial_account_repository.dart';
import '../repositories/wallet_repository.dart';
import 'financial_account_wallet_bridge.dart';

/// Phase 7A — Financial Account Sync Summary Result
///
/// Encapsulates the deterministic outcome of a non-destructive synchronization
/// cycle between the authoritative [Wallet] system and [FinancialAccount] records.
class FinancialAccountSyncResult {
  const FinancialAccountSyncResult({
    required this.totalWallets,
    required this.accountsCreated,
    required this.accountsUpdated,
    required this.accountsUnchanged,
    required this.untouchedNonWalletAccounts,
  });

  final int totalWallets;
  final int accountsCreated;
  final int accountsUpdated;
  final int accountsUnchanged;
  final int untouchedNonWalletAccounts;

  @override
  String toString() =>
      'FinancialAccountSyncResult(totalWallets: $totalWallets, created: $accountsCreated, updated: $accountsUpdated, unchanged: $accountsUnchanged, untouchedNonWallet: $untouchedNonWalletAccounts)';
}

/// Phase 7A — Non-Destructive Financial Account Synchronization Service
///
/// Synchronizes existing [Wallet] records into [FinancialAccount] storage.
///
/// Invariants & Rules:
/// - Wallet remains authoritative for legacy wallet data.
/// - Existing FinancialAccounts created manually (without a matching legacyWalletId) are never overwritten.
/// - Only accounts with matching legacyWalletId (or deterministic bridge ID) are updated.
/// - Never deletes FinancialAccounts that have no matching Wallet.
/// - Never duplicates accounts for the same Wallet.
/// - Never touches transactions.
/// - Never modifies Wallet records.
/// - Local-first, deterministic, zero network or external dependencies.
class FinancialAccountSyncService {
  FinancialAccountSyncService({
    WalletRepository? walletRepository,
    FinancialAccountRepository? accountRepository,
  })  : _walletRepository = walletRepository ?? WalletRepository.instance,
        _accountRepository =
            accountRepository ?? FinancialAccountRepository.instance;

  FinancialAccountSyncService._()
      : _walletRepository = WalletRepository.instance,
        _accountRepository = FinancialAccountRepository.instance;

  static final FinancialAccountSyncService instance =
      FinancialAccountSyncService._();

  final WalletRepository _walletRepository;
  final FinancialAccountRepository _accountRepository;

  /// Performs a safe, non-destructive synchronization of [Wallet] records into [FinancialAccount]s.
  ///
  /// If [wallets] is provided, uses that list; otherwise reads directly from [_walletRepository].
  Future<FinancialAccountSyncResult> syncWalletsToFinancialAccounts({
    List<Wallet>? wallets,
    DateTime? syncTimestamp,
  }) async {
    await _accountRepository.init();

    final sourceWallets = wallets ?? await _walletRepository.getAll();
    final existingAccounts = await _accountRepository.getAll();

    // Index existing accounts by legacyWalletId and by deterministic bridge ID
    final accountsByLegacyId = <String, FinancialAccount>{};
    final accountsById = <String, FinancialAccount>{};

    for (final acc in existingAccounts) {
      accountsById[acc.id] = acc;
      if (acc.legacyWalletId != null && acc.legacyWalletId!.isNotEmpty) {
        accountsByLegacyId[acc.legacyWalletId!] = acc;
      }
    }

    int created = 0;
    int updated = 0;
    int unchanged = 0;
    final matchedExistingAccountIds = <String>{};

    final now = syncTimestamp ?? DateTime.now();

    for (final wallet in sourceWallets) {
      final expectedBridgeId =
          FinancialAccountWalletBridge.deterministicAccountId(wallet.id);

      // Find matching existing account by legacyWalletId or bridge ID
      final existing =
          accountsByLegacyId[wallet.id] ?? accountsById[expectedBridgeId];

      if (existing != null) {
        matchedExistingAccountIds.add(existing.id);

        final targetType =
            FinancialAccountWalletBridge.mapWalletType(wallet.type);
        final targetActive = !wallet.isArchived;

        final isDifferent = existing.name != wallet.name ||
            existing.balance != wallet.currentBalance ||
            existing.type != targetType ||
            existing.isActive != targetActive ||
            existing.legacyWalletId != wallet.id;

        if (isDifferent) {
          final updatedAccount = existing.copyWith(
            name: wallet.name,
            balance: wallet.currentBalance,
            type: targetType,
            isActive: targetActive,
            legacyWalletId: wallet.id,
            updatedAt: now,
          );
          await _accountRepository.saveAccount(updatedAccount);
          updated++;
        } else {
          unchanged++;
        }
      } else {
        // Create new bridged account
        final newAccount = FinancialAccountWalletBridge.fromWallet(
          wallet,
          updatedAt: now,
        );
        await _accountRepository.saveAccount(newAccount);
        created++;
      }
    }

    final untouchedNonWalletCount =
        existingAccounts.length - matchedExistingAccountIds.length;

    return FinancialAccountSyncResult(
      totalWallets: sourceWallets.length,
      accountsCreated: created,
      accountsUpdated: updated,
      accountsUnchanged: unchanged,
      untouchedNonWalletAccounts:
          untouchedNonWalletCount > 0 ? untouchedNonWalletCount : 0,
    );
  }
}
