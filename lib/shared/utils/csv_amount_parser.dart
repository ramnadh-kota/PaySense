/// CSV BANK STATEMENT IMPORT — PHASE 5. Pure Dart, deterministic amount
/// parsing. Strips only KNOWN formatting noise (currency symbol, thousand
/// separators, whitespace) — if anything else remains, the amount is
/// treated as malformed (returns null) rather than silently reinterpreted.
class CsvAmountParser {
  CsvAmountParser._();

  static final RegExp _validNumber = RegExp(r'^-?\d+(\.\d+)?$');

  /// Parses formats such as `₹1,250.00`, `1,250.00`, `1250`, `1,250`.
  /// Returns null for empty/missing cells AND for anything that doesn't
  /// cleanly resolve to a number after removing the currency symbol,
  /// commas, and whitespace — never guesses at a malformed value.
  static double? parse(String? raw) {
    if (raw == null) return null;
    var value = raw.trim();
    if (value.isEmpty) return null;

    value = value.replaceAll('₹', '').replaceAll('Rs.', '').replaceAll('Rs', '');
    value = value.replaceAll(RegExp(r'\s'), '');
    value = value.replaceAll(',', '');

    if (value.isEmpty || !_validNumber.hasMatch(value)) return null;
    return double.tryParse(value);
  }

  /// True when [raw] is present but not empty-ish (used to distinguish a
  /// genuinely blank cell from one that failed to parse).
  static bool hasContent(String? raw) => raw != null && raw.trim().isNotEmpty;
}
