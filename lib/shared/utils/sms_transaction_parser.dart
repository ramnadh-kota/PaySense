import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// Whether a parsed SMS represents money leaving or entering the user's
/// account.
enum SmsTransactionDirection { debit, credit }

/// The result of parsing one bank/UPI SMS. This is a pure, in-memory value
/// — nothing here is persisted, logged, or sent anywhere. The raw SMS body
/// is intentionally NOT retained on this object; only the minimum
/// transaction fields extracted from it are kept, per the requirement to
/// discard raw SMS content after parsing.
@immutable
class ParsedSmsTransaction {
  const ParsedSmsTransaction({
    required this.amount,
    required this.direction,
    required this.sender,
    required this.timestamp,
    required this.confidence,
    required this.fingerprint,
    this.merchant,
    this.isLikelyTransfer = false,
  });

  final double amount;
  final SmsTransactionDirection direction;
  final String sender;
  final DateTime timestamp;

  /// 0.0-1.0. How confident the parser is that this is a genuine,
  /// unambiguous transaction with a correctly identified direction.
  final double confidence;

  /// Stable dedup key — see [SmsTransactionParser.buildFingerprint].
  final String fingerprint;

  /// Best-effort merchant/counterparty name, or null when none could be
  /// reliably identified (never fabricated).
  final String? merchant;

  /// True when the message looks like a transfer between the user's own
  /// accounts rather than a genuine income/expense event.
  final bool isLikelyTransfer;

  /// Below this, a caller should treat the result as "possible transaction
  /// detected" requiring explicit user review rather than auto-adding it.
  static const double autoAddConfidenceThreshold = 0.85;

  bool get isHighConfidence => confidence >= autoAddConfidenceThreshold;
}

/// Pure SMS-to-transaction-fields parser. No platform/permission
/// dependency of any kind — this class never reads SMS itself; it only
/// transforms an already-obtained (sender, body, timestamp) triple into
/// structured fields. Deliberately biased toward precision over recall:
/// when in doubt, it returns null or a low-confidence result rather than
/// guessing, since a fabricated transaction is far worse than a missed one.
class SmsTransactionParser {
  SmsTransactionParser._();

  static final RegExp _amountPattern = RegExp(
    r'(?:rs\.?|inr|₹)\s?([\d,]+(?:\.\d{1,2})?)',
    caseSensitive: false,
  );

  static final RegExp _debitPattern = RegExp(
    r'\b(debited|debit|spent|paid|withdrawn|withdrew|used)\b',
    caseSensitive: false,
  );

  static final RegExp _creditPattern = RegExp(
    r'\b(credited|credit|received|deposited)\b',
    caseSensitive: false,
  );

  static final RegExp _transferPattern = RegExp(
    r'\b(transferred|transfer)\b.*\b(own|self)\b|\b(own|self)\b.*\btransfer(red)?\b',
    caseSensitive: false,
  );

  /// An OTP/verification-code message can legitimately mention a pending
  /// amount ("Rs.5000 will be debited... use OTP 123456 to authorize") —
  /// that's a *request* for authorization, not a completed transaction. Real
  /// post-transaction bank SMS don't themselves contain the word OTP, so
  /// this is a safe, hard override: matching this pattern means "never a
  /// transaction," regardless of what else the message says.
  static final RegExp _otpPattern = RegExp(
    r'\b(otp|one[- ]?time password|verification code|security code)\b',
    caseSensitive: false,
  );

  /// A transaction that didn't actually happen — no real balance movement,
  /// so it must never become a Transaction or reach review as one.
  /// Deliberately excludes words like "reversed"/"refunded", which usually
  /// describe a real completed credit.
  static final RegExp _noMovementPattern = RegExp(
    r'\b(failed|declined|unsuccessful|not processed|insufficient balance|has been rejected)\b',
    caseSensitive: false,
  );

  /// Weak signal that a message is finance-related even without a clear
  /// debit/credit verb — present alongside an amount, this still isn't
  /// enough to auto-add, but it's enough to surface for user review rather
  /// than discard as unrelated to money entirely.
  static final RegExp _weakFinancialContextPattern = RegExp(
    r'\b(a/c|account|txn|transaction|bank|balance)\b',
    caseSensitive: false,
  );

  static final RegExp _merchantPattern = RegExp(
    r"\b(?:at|to)\s+([A-Za-z][A-Za-z0-9&.\-' ]{1,29}?)(?:\s+on\b|\s+via\b|\s+for\b|[.,]|$)",
    caseSensitive: false,
  );

  /// Parses one SMS. Returns null when the message doesn't contain a clear
  /// amount, or contains an amount with no financial-context signal at all
  /// (e.g. a promotional message) — never guesses a transaction into
  /// existence from an arbitrary message.
  static ParsedSmsTransaction? parse({
    required String sender,
    required String body,
    required DateTime timestamp,
  }) {
    final trimmedBody = body.trim();
    if (trimmedBody.isEmpty) {
      return null;
    }

    if (_otpPattern.hasMatch(trimmedBody)) {
      // A one-time-password prompt, even one that quotes a pending amount,
      // is never a completed transaction — see [_otpPattern].
      return null;
    }

    if (_noMovementPattern.hasMatch(trimmedBody)) {
      // No real money moved — see [_noMovementPattern].
      return null;
    }

    final amountMatch = _amountPattern.firstMatch(trimmedBody);
    if (amountMatch == null) {
      return null;
    }

    final amount = double.tryParse(amountMatch.group(1)!.replaceAll(',', ''));
    if (amount == null || amount <= 0) {
      return null;
    }

    final normalizedBody = trimmedBody.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    final fingerprint = buildFingerprint(
      sender: sender,
      timestamp: timestamp,
      normalizedBody: normalizedBody,
    );
    final merchantMatch = _merchantPattern.firstMatch(trimmedBody);
    final merchant = merchantMatch?.group(1)?.trim();

    final hasTransferKeyword = _transferPattern.hasMatch(trimmedBody);
    final hasDebitKeyword = _debitPattern.hasMatch(trimmedBody);
    final hasCreditKeyword = _creditPattern.hasMatch(trimmedBody);

    if (hasTransferKeyword) {
      // A transfer between the user's own accounts is never auto-classified
      // as income/expense — flagged distinctly and scored low so a caller
      // never auto-adds it.
      return ParsedSmsTransaction(
        amount: amount,
        direction: hasCreditKeyword
            ? SmsTransactionDirection.credit
            : SmsTransactionDirection.debit,
        sender: sender.trim(),
        timestamp: timestamp,
        confidence: 0.3,
        fingerprint: fingerprint,
        merchant: (merchant == null || merchant.isEmpty) ? null : merchant,
        isLikelyTransfer: true,
      );
    }

    if (hasDebitKeyword || hasCreditKeyword) {
      final ambiguous = hasDebitKeyword && hasCreditKeyword;
      return ParsedSmsTransaction(
        amount: amount,
        // Ambiguous messages default to debit — a spurious auto-added
        // expense is easier for a user to notice/correct than a spurious
        // auto-added income inflating their balance.
        direction: hasDebitKeyword
            ? SmsTransactionDirection.debit
            : SmsTransactionDirection.credit,
        sender: sender.trim(),
        timestamp: timestamp,
        confidence: ambiguous ? 0.4 : 0.9,
        fingerprint: fingerprint,
        merchant: (merchant == null || merchant.isEmpty) ? null : merchant,
      );
    }

    if (_weakFinancialContextPattern.hasMatch(trimmedBody)) {
      // An amount plus some banking-ish context, but no clear direction
      // verb — surfaced at low confidence for review, not auto-added.
      return ParsedSmsTransaction(
        amount: amount,
        direction: SmsTransactionDirection.debit,
        sender: sender.trim(),
        timestamp: timestamp,
        confidence: 0.3,
        fingerprint: fingerprint,
        merchant: (merchant == null || merchant.isEmpty) ? null : merchant,
      );
    }

    // An amount with no financial-context signal whatsoever (no direction
    // verb, no banking keyword) — most likely promotional/non-financial.
    return null;
  }

  /// A stable deduplication key built from [sender], [timestamp] rounded to
  /// the minute, and [normalizedBody] — deliberately NOT message-text-only,
  /// since two legitimate transactions (e.g. the same coffee shop on two
  /// different days) can produce near-identical message text and must not
  /// be deduplicated against each other. Rounding to the minute (rather
  /// than using an exact timestamp) absorbs redelivery/reprocessing of the
  /// literal same SMS, which can arrive with a slightly different
  /// processing timestamp.
  static String buildFingerprint({
    required String sender,
    required DateTime timestamp,
    required String normalizedBody,
  }) {
    final roundedMinute = DateTime(
      timestamp.year,
      timestamp.month,
      timestamp.day,
      timestamp.hour,
      timestamp.minute,
    );
    final raw =
        '${sender.trim().toLowerCase()}|${roundedMinute.toIso8601String()}|$normalizedBody';
    return sha256.convert(utf8.encode(raw)).toString();
  }
}
