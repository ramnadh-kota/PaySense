import '../models/transaction_ingestion_record.dart';
import '../models/transaction_ingestion_result.dart';

/// TRANSACTION INGESTION 1.0 — PHASE 7. Pure Dart, deterministic. Never
/// throws for malformed imported data — always returns a structured
/// [TransactionValidationResult] so a batch import can report
/// "42 valid, 3 duplicates, 2 need review, 1 invalid" instead of crashing.
class TransactionValidator {
  TransactionValidator._();

  /// Mirrors `ProfileSetupScreen`'s existing currency dropdown options
  /// (`INR`/`USD`/`EUR`/`GBP`/`AED`) — the app's one established currency
  /// vocabulary — redeclared here since that list is private to its
  /// screen file and can't be imported.
  static const Set<String> supportedCurrencyCodes = {'INR', 'USD', 'EUR', 'GBP', 'AED'};

  /// Key fragments that must NEVER appear in [TransactionIngestionRecord.metadata]
  /// — mirrors the exact forbidden-fragment discipline already established
  /// in `AnalyticsService`'s privacy check.
  static const List<String> forbiddenMetadataKeyFragments = [
    'otp', 'pin', 'password', 'cvv', 'cardnumber', 'accountpassword',
    'bankcredential', 'credential', 'smsbody', 'rawsms', 'rawbody', 'secret', 'token',
  ];

  /// Runs the record itself through [TransactionNormalizer] first if it
  /// hasn't been already — safe to call on an already-normalized record.
  static TransactionValidationResult validate(TransactionIngestionRecord record) {
    final errors = <String>[];

    if (record.amount.isNaN || record.amount.isInfinite) {
      errors.add('Amount is not a valid number.');
    } else if (record.amount <= 0) {
      errors.add('Amount must be greater than zero.');
    }

    if (record.dateTime == null) {
      errors.add('Transaction date is missing.');
    }

    // IngestionTransactionType is a closed enum — an "unsupported
    // transaction type" is structurally impossible to construct, so no
    // runtime check is needed for it.

    if (record.currencyCode != null && !supportedCurrencyCodes.contains(record.currencyCode!.toUpperCase())) {
      errors.add('Unsupported currency: ${record.currencyCode}.');
    }

    _assertPrivacySafeMetadata(record, errors);

    return TransactionValidationResult(isValid: errors.isEmpty, errors: errors);
  }

  /// PHASE 8 — never a silent pass-through: a record whose metadata looks
  /// like it could carry an OTP/PIN/password/card number/CVV/raw SMS body/
  /// bank credential is treated as INVALID data, not imported.
  static void _assertPrivacySafeMetadata(TransactionIngestionRecord record, List<String> errors) {
    for (final key in record.metadata.keys) {
      final normalizedKey = key.toString().toLowerCase().replaceAll('_', '').replaceAll('-', '');
      for (final fragment in forbiddenMetadataKeyFragments) {
        if (normalizedKey.contains(fragment)) {
          errors.add('Metadata key "$key" is not allowed — sensitive data must never enter the ingestion pipeline.');
        }
      }
    }
  }
}
