import '../models/financial_account.dart';
import '../models/wallet.dart';

/// Phase 7A — Financial Account Wallet Compatibility Bridge
///
/// A pure, deterministic compatibility layer bridging the existing [Wallet] system
/// into unified [FinancialAccount] representations.
///
/// Rules:
/// - Pure transformation with zero side-effects or database writes.
/// - Deterministic `FinancialAccount.id` derived from `Wallet.id`.
/// - Preserves `wallet.id` via `legacyWalletId`.
/// - Preserves exact name, balance, creation timestamps, and active/archive status.
/// - Maps types conservatively without fabricating bank metadata.
/// - Preserves asset vs liability semantics.
/// - Does not mutate original [Wallet] instances.
class FinancialAccountWalletBridge {
  const FinancialAccountWalletBridge._();

  /// Deterministic ID generator for financial accounts bridged from wallets.
  static String deterministicAccountId(String walletId) => 'wallet_$walletId';

  /// Conservatively maps a free-form [Wallet.type] string to a [FinancialAccountType].
  static FinancialAccountType mapWalletType(String? walletType) {
    if (walletType == null || walletType.trim().isEmpty) {
      return FinancialAccountType.other;
    }

    final cleaned = walletType.trim().toLowerCase();
    switch (cleaned) {
      case 'bank':
      case 'savings':
      case 'checking':
      case 'current':
      case 'salary':
      case 'deposit':
        return FinancialAccountType.bank;
      case 'cash':
      case 'petty cash':
        return FinancialAccountType.cash;
      case 'credit card':
      case 'creditcard':
      case 'credit_card':
      case 'credit':
        return FinancialAccountType.creditCard;
      case 'upi':
        return FinancialAccountType.upi;
      case 'wallet':
      case 'upi/wallet':
      case 'upi / wallet':
      case 'digital wallet':
      case 'prepaid':
        return FinancialAccountType.wallet;
      case 'other':
        return FinancialAccountType.other;
      default:
        if (cleaned.contains('credit')) {
          return FinancialAccountType.creditCard;
        }
        if (cleaned.contains('bank') ||
            cleaned.contains('saving') ||
            cleaned.contains('salary') ||
            cleaned.contains('deposit')) {
          return FinancialAccountType.bank;
        }
        if (cleaned.contains('cash')) {
          return FinancialAccountType.cash;
        }
        if (cleaned.contains('upi') && !cleaned.contains('wallet')) {
          return FinancialAccountType.upi;
        }
        if (cleaned.contains('wallet')) {
          return FinancialAccountType.wallet;
        }
        return FinancialAccountType.other;
    }
  }

  /// Maps a single [Wallet] to an immutable, deterministic [FinancialAccount].
  ///
  /// If [updatedAt] is not provided, defaults to [wallet.createdAt] for pure determinism.
  static FinancialAccount fromWallet(
    Wallet wallet, {
    DateTime? updatedAt,
  }) {
    return FinancialAccount(
      id: deterministicAccountId(wallet.id),
      name: wallet.name,
      type: mapWalletType(wallet.type),
      source: FinancialAccountSource.manual,
      balance: wallet.currentBalance,
      currency: 'INR',
      isActive: !wallet.isArchived,
      createdAt: wallet.createdAt,
      updatedAt: updatedAt ?? wallet.createdAt,
      legacyWalletId: wallet.id,
    );
  }

  /// Converts a collection of [Wallet]s to a list of [FinancialAccount]s.
  ///
  /// Returns an unmodifiable list preserving the input ordering.
  static List<FinancialAccount> fromWallets(
    List<Wallet> wallets, {
    DateTime? updatedAt,
  }) {
    return List<FinancialAccount>.unmodifiable(
      wallets.map((wallet) => fromWallet(wallet, updatedAt: updatedAt)),
    );
  }
}

/// Standalone top-level convenience alias for [FinancialAccountWalletBridge.fromWallet].
FinancialAccount fromWallet(Wallet wallet, {DateTime? updatedAt}) =>
    FinancialAccountWalletBridge.fromWallet(wallet, updatedAt: updatedAt);

/// Standalone top-level convenience alias for [FinancialAccountWalletBridge.fromWallets].
List<FinancialAccount> fromWallets(List<Wallet> wallets, {DateTime? updatedAt}) =>
    FinancialAccountWalletBridge.fromWallets(wallets, updatedAt: updatedAt);
