import '../models/wallet.dart';

/// Resolves an "account" reference — as stored on a [Transaction],
/// [Bill], [Loan], or [RecurringTransaction]'s `accountId` field — to the
/// real [Wallet.id] a balance mutation or ledger record should target.
///
/// This is the single centralized resolver for the whole app. It never
/// guesses:
///
/// 1. If [accountId] already equals an existing wallet's id, it's returned
///    unchanged — this is the common case for anything created through the
///    current wallet-selection UI (Add Expense/Income, wallet-to-wallet
///    Transfer), which stores the real id directly.
/// 2. Else, if [accountId] exactly matches exactly one wallet's [Wallet.name]
///    (case-sensitive — names are user-chosen and should be matched
///    precisely), that wallet's id is returned.
/// 3. Else, if [accountId] is a legacy display label ('Cash'/'Checking'/
///    'Savings'/'Credit Card') and exactly one wallet's [Wallet.type]
///    matches it case-insensitively, that wallet's id is returned.
/// 4. Otherwise — no candidate, or more than one equally-plausible
///    candidate — this returns null rather than guess which wallet the
///    user meant. Callers decide how to handle that (e.g. a legacy
///    hardcoded fallback for old records, or leaving data untouched during
///    migration).
String? resolveWalletIdForAccount(String? accountId, List<Wallet> wallets) {
  if (accountId == null || accountId.isEmpty) {
    return null;
  }

  if (wallets.any((wallet) => wallet.id == accountId)) {
    return accountId;
  }

  final byName = wallets.where((wallet) => wallet.name == accountId).toList();
  if (byName.length == 1) {
    return byName.single.id;
  }

  final byType = wallets
      .where((wallet) => wallet.type.toLowerCase() == accountId.toLowerCase())
      .toList();
  if (byType.length == 1) {
    return byType.single.id;
  }

  return null;
}

/// Legacy last-resort fallback: the original two-bucket mapping used before
/// [resolveWalletIdForAccount] existed ('Cash' -> a fixed synthetic id,
/// everything else -> another fixed synthetic id). Kept only so behavior for
/// very old, still-unresolved records doesn't regress — prefer
/// [resolveWalletIdForAccount] everywhere else, since this makes no attempt
/// to match a real wallet and can return an id that doesn't correspond to
/// any wallet that actually exists.
String resolveDisplayAccountToWalletId(String? account) {
  switch (account) {
    case 'Cash':
      return 'wallet-cash';
    case 'Checking':
    case 'Savings':
    case 'Credit Card':
    default:
      return 'wallet-hdfc-salary';
  }
}
