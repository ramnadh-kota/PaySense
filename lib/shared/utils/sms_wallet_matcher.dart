import 'package:paysense/shared/models/wallet.dart';

/// Result of trying to attribute a parsed SMS to one of the user's wallets.
/// [walletId] is only ever non-null when exactly one wallet could be
/// identified with confidence — this matcher never guesses between two or
/// more plausible candidates.
class SmsWalletMatch {
  const SmsWalletMatch({this.walletId, this.isAmbiguous = false});

  /// The one confidently-matched wallet, or null when no match (or more
  /// than one candidate) was found.
  final String? walletId;

  /// True when more than one wallet was equally plausible — distinct from
  /// "no match at all" so callers can message the review item differently
  /// if desired, though both cases require the user to choose explicitly.
  final bool isAmbiguous;

  bool get isConfident => walletId != null;
}

/// Result of trying to attribute a likely-transfer SMS to a source and
/// destination wallet pair.
class SmsTransferMatch {
  const SmsTransferMatch({this.sourceWalletId, this.destinationWalletId});

  final String? sourceWalletId;
  final String? destinationWalletId;

  /// True only when both legs resolved to exactly one wallet each, and
  /// they're two different wallets — the only situation in which an
  /// automatic transfer should ever be created.
  bool get isConfident =>
      sourceWalletId != null &&
      destinationWalletId != null &&
      sourceWalletId != destinationWalletId;
}

/// Attributes a parsed SMS (by its originating [sender] and, optionally,
/// extracted [merchant] text) to one of the user's wallets. Deliberately
/// biased toward "no match" over a wrong guess:
///
/// 1. Explicit bank identifier: the SMS sender code (e.g. "HDFCBK") is
///    checked against each wallet's bank name/name. Exactly one match wins;
///    two or more is treated as ambiguous, never guessed between (this is
///    the case from the spec: "HDFC Salary" + "HDFC Savings" both matching
///    sender "HDFC...").
/// 2. A user-configured sender→wallet relationship is a natural future
///    extension point here, not yet built (no settings UI for it exists).
/// 3. The same check against [merchant] text, when the sender alone didn't
///    resolve anything (covers "to `wallet name`"-style bodies).
/// 4. If the whole app only has one eligible wallet, there is nothing to
///    disambiguate between, so it's used directly.
SmsWalletMatch matchWalletForSms({
  required String sender,
  String? merchant,
  required List<Wallet> wallets,
}) {
  final eligible = wallets.where((wallet) => !wallet.isArchived).toList();
  if (eligible.isEmpty) {
    return const SmsWalletMatch();
  }

  final bySender = _uniqueMatch(
    eligible,
    (wallet) => _identifierAppearsIn(sender, wallet),
  );
  if (bySender.walletId != null) {
    return SmsWalletMatch(walletId: bySender.walletId);
  }
  if (bySender.isAmbiguous) {
    return const SmsWalletMatch(isAmbiguous: true);
  }

  if (merchant != null && merchant.trim().isNotEmpty) {
    final byMerchant = _uniqueMatch(
      eligible,
      (wallet) => _identifierAppearsIn(merchant, wallet),
    );
    if (byMerchant.walletId != null) {
      return SmsWalletMatch(walletId: byMerchant.walletId);
    }
    if (byMerchant.isAmbiguous) {
      return const SmsWalletMatch(isAmbiguous: true);
    }
  }

  if (eligible.length == 1) {
    return SmsWalletMatch(walletId: eligible.single.id);
  }

  return const SmsWalletMatch();
}

/// Attributes a likely-transfer SMS to a source (matched via [sender]) and
/// destination (matched via [merchant], e.g. the "to X" fragment) wallet.
/// Never guesses — either both legs resolve to exactly one wallet each, or
/// the transfer must go to manual review.
SmsTransferMatch matchTransferWallets({
  required String sender,
  String? merchant,
  required List<Wallet> wallets,
}) {
  final eligible = wallets.where((wallet) => !wallet.isArchived).toList();

  final source = _uniqueMatch(
    eligible,
    (wallet) => _identifierAppearsIn(sender, wallet),
  );

  String? destinationId;
  if (merchant != null && merchant.trim().isNotEmpty) {
    final destination = _uniqueMatch(
      eligible,
      (wallet) => _identifierAppearsIn(merchant, wallet),
    );
    destinationId = destination.walletId;
  }

  return SmsTransferMatch(
    sourceWalletId: source.walletId,
    destinationWalletId: destinationId,
  );
}

class _MatchResult {
  const _MatchResult({this.walletId, this.isAmbiguous = false});

  final String? walletId;
  final bool isAmbiguous;
}

_MatchResult _uniqueMatch(
  List<Wallet> wallets,
  bool Function(Wallet wallet) predicate,
) {
  final candidates = wallets.where(predicate).toList();
  if (candidates.isEmpty) {
    return const _MatchResult();
  }
  if (candidates.length > 1) {
    return const _MatchResult(isAmbiguous: true);
  }
  return _MatchResult(walletId: candidates.single.id);
}

/// True when [wallet]'s bank name or wallet name shows up inside [text] —
/// both sides normalized to letters/digits only so formatting differences
/// ("HDFC Bank" vs "HDFCBK") don't prevent an otherwise-clear match. A
/// minimum length guards against a single stray letter matching everything.
bool _identifierAppearsIn(String text, Wallet wallet) {
  final normalizedText = _normalize(text);
  if (normalizedText.length < 3) {
    return false;
  }
  for (final identifier in [wallet.bankName, wallet.name]) {
    final normalizedIdentifier = _normalize(identifier);
    if (normalizedIdentifier.length < 3) {
      continue;
    }
    if (normalizedText.contains(normalizedIdentifier) ||
        normalizedIdentifier.contains(normalizedText)) {
      return true;
    }
  }
  return false;
}

String _normalize(String value) {
  return value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
}
