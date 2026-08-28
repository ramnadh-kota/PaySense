import 'package:flutter/foundation.dart';

/// TRANSACTION INGESTION 1.0 — PHASE 1 (foundation only). Pure Dart, zero
/// Flutter-widget/Riverpod/Hive-box dependency (the `@immutable` annotation
/// is the only `flutter/foundation.dart` usage, matching every other pure
/// model in this codebase).
///
/// [TransactionSource] is the closed set of places a transaction can come
/// from. New sources must be addable here without touching any downstream
/// normalization/fingerprinting/deduplication logic — those all operate on
/// [TransactionIngestionRecord], never on the source directly.
enum TransactionSource { manual, sms, csv, pdf, accountAggregator, api }

extension TransactionSourceLabel on TransactionSource {
  String get label {
    switch (this) {
      case TransactionSource.manual:
        return 'Manual entry';
      case TransactionSource.sms:
        return 'SMS';
      case TransactionSource.csv:
        return 'CSV / bank statement';
      case TransactionSource.pdf:
        return 'PDF statement';
      case TransactionSource.accountAggregator:
        return 'Account Aggregator';
      case TransactionSource.api:
        return 'Bank API';
    }
  }

  /// Machine-safe serialization value — `.name` is already stable
  /// lowerCamelCase; exposed explicitly so call sites never hardcode a
  /// raw string literal instead of this enum.
  String get key => name;
}

/// The ingestion-layer's own notion of transaction direction/kind.
/// Deliberately a SUPERSET of the existing [Transaction.transactionType]
/// string convention (`'income'`/`'expense'`/`'transfer'`, confirmed via a
/// full-repo grep — no `'refund'` value exists anywhere in the canonical
/// model or the existing SMS parser). `refund` is real at the ingestion
/// layer (it changes how fingerprinting/deduplication must treat a record
/// — see PHASE 5/6 docs) but is honestly mapped down to `'income'` when it
/// eventually reaches the existing [Transaction] model, exactly matching
/// how the existing SMS parser already treats a refund SMS as a normal
/// credit/income transaction (its own comment: a refund is a real
/// completed credit, not something requiring special handling).
enum IngestionTransactionType { income, expense, transfer, refund }

extension IngestionTransactionTypeMapping on IngestionTransactionType {
  /// Maps to the EXISTING `Transaction.transactionType` string convention.
  /// This is the ONLY place that conversion happens — never duplicated at
  /// a call site.
  String toTransactionTypeString() {
    switch (this) {
      case IngestionTransactionType.income:
        return 'income';
      case IngestionTransactionType.expense:
        return 'expense';
      case IngestionTransactionType.transfer:
        return 'transfer';
      case IngestionTransactionType.refund:
        return 'income';
    }
  }
}

/// A tri-state (+unknown) confidence bucket, deliberately mirroring the
/// EXISTING `SmsConfidenceTier`/`ParsedSmsTransaction.autoAddConfidenceThreshold`
/// vocabulary and thresholds (`sms_transaction_processor.dart`) for
/// consistency — but independently defined here with NO import of/coupling
/// to any SMS file, per this phase's explicit "do not touch SMS" boundary.
/// Manual entry is always [high] (the user typed it themselves); imported
/// sources vary.
enum IngestionConfidenceTier { high, medium, low, unknown }

IngestionConfidenceTier ingestionConfidenceTierFor(double? confidence) {
  if (confidence == null) return IngestionConfidenceTier.unknown;
  if (confidence >= 0.85) return IngestionConfidenceTier.high;
  if (confidence >= 0.3) return IngestionConfidenceTier.medium;
  return IngestionConfidenceTier.low;
}

/// The normalized representation used BEFORE a transaction is persisted —
/// NOT a replacement for the existing `Transaction` model. Field types are
/// chosen to be directly compatible with `Transaction`'s existing fields
/// (`amount: double`, dates as plain `DateTime`, `categoryId`/`walletId`
/// as raw `String`s matching `Transaction.categoryId`/`accountId`'s
/// existing "just a string, not an enum" convention) so a future
/// persistence step (NOT built in this phase) can construct a real
/// `Transaction` with minimal translation.
///
/// PRIVACY RULE (PHASE 8): this model structurally has NO field capable of
/// holding an OTP, PIN, password, card number, CVV, full SMS body, or bank
/// credential — there is no `rawBody`/`smsBody`/`credentials` field of any
/// kind. The only free-form field is [metadata], which exists solely for
/// small, safe, source-specific extras (e.g. a CSV row number) — see
/// `TransactionValidator`'s forbidden-key-fragment check, which mirrors
/// the same privacy discipline already established in `AnalyticsService`.
@immutable
class TransactionIngestionRecord {
  const TransactionIngestionRecord({
    required this.source,
    required this.type,
    required this.amount,
    this.sourceTransactionId,
    this.dateTime,
    this.merchant,
    this.description,
    this.categoryId,
    this.walletId,
    this.currencyCode,
    this.referenceId,
    this.confidence,
    this.metadata = const {},
  });

  final TransactionSource source;
  final IngestionTransactionType type;
  final double amount;

  /// The SOURCE system's own identifier for this specific record (e.g. a
  /// CSV row hash, an Account Aggregator transaction id). Distinct from
  /// [referenceId] (a bank-level reference/UTR that could appear
  /// identically across multiple DIFFERENT sources for the SAME
  /// real-world transaction) — both are used by fingerprinting, see
  /// `TransactionFingerprintCalculator`.
  final String? sourceTransactionId;

  /// Nullable — a source that failed to parse a date should surface that
  /// as a validation error, not silently default to `DateTime.now()`
  /// (never fabricated).
  final DateTime? dateTime;

  /// Best-effort merchant/payee text — nullable, never fabricated when a
  /// source doesn't provide one.
  final String? merchant;

  final String? description;

  /// Matches `Transaction.categoryId`'s existing convention: a raw
  /// string, not an enum. Nullable since most import sources won't know a
  /// category until a later (not-yet-built) mapping step.
  final String? categoryId;

  /// Matches `Transaction.accountId`'s existing convention (expected to
  /// equal a real `Wallet.id`). Nullable for the same reason as
  /// [categoryId] — wallet mapping is a future-phase UI concern.
  final String? walletId;

  /// Nullable — `Transaction`/`Wallet` have NO currency field today
  /// (confirmed); currency is a single app-wide `UserProfile.currency`
  /// setting. This field exists only so a future multi-currency import
  /// source can flag a mismatch, never assumed persisted.
  final String? currencyCode;

  /// A bank-level reference/UTR number, when the source provides one —
  /// the strongest available signal for cross-source deduplication (see
  /// PHASE 5).
  final String? referenceId;

  /// 0.0–1.0, nullable. Manual entry should pass `1.0`; imported sources
  /// pass whatever their own extraction confidence was.
  final double? confidence;

  /// Small, safe, source-specific extras ONLY. NEVER an OTP/PIN/password/
  /// card number/CVV/raw SMS body/bank credential — see the class doc's
  /// PRIVACY RULE.
  final Map<String, dynamic> metadata;

  TransactionIngestionRecord copyWith({
    TransactionSource? source,
    IngestionTransactionType? type,
    double? amount,
    String? sourceTransactionId,
    DateTime? dateTime,
    String? merchant,
    String? description,
    String? categoryId,
    String? walletId,
    String? currencyCode,
    String? referenceId,
    double? confidence,
    Map<String, dynamic>? metadata,
  }) {
    return TransactionIngestionRecord(
      source: source ?? this.source,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      sourceTransactionId: sourceTransactionId ?? this.sourceTransactionId,
      dateTime: dateTime ?? this.dateTime,
      merchant: merchant ?? this.merchant,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      walletId: walletId ?? this.walletId,
      currencyCode: currencyCode ?? this.currencyCode,
      referenceId: referenceId ?? this.referenceId,
      confidence: confidence ?? this.confidence,
      metadata: metadata ?? this.metadata,
    );
  }
}
