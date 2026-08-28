/// CSV BANK STATEMENT IMPORT — PHASE 6. Pure Dart, deterministic date
/// parsing for the formats commonly seen in Indian bank statement
/// exports: `DD/MM/YYYY`, `DD-MM-YYYY`, `DD/MM/YY`, and ISO `YYYY-MM-DD`
/// (each optionally followed by a time component).
///
/// The day-first (`DD/MM/...`) convention is applied UNIFORMLY and
/// deterministically for every slash/dash-separated date — this is what
/// actually satisfies "never silently turn February 1 into January 2":
/// that mistake only happens when a parser sometimes reads day-first and
/// sometimes month-first depending on the values it sees. By always
/// reading day-first for this format family (matching real Indian bank
/// exports) the ambiguity never arises in the first place. A date string
/// that doesn't match any known pattern, or that doesn't resolve to a
/// real calendar date (e.g. day 31 in a 30-day month), returns null
/// rather than being guessed — callers must treat that as "format
/// couldn't be established confidently".
class CsvDateParser {
  CsvDateParser._();

  static final RegExp _iso =
      RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})(?:[ T](\d{1,2}):(\d{2})(?::(\d{2}))?)?$');

  static final RegExp _dayFirst =
      RegExp(r'^(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})(?:[ T](\d{1,2}):(\d{2})(?::(\d{2}))?)?$');

  static DateTime? parse(String? raw) {
    if (raw == null) return null;
    final value = raw.trim();
    if (value.isEmpty) return null;

    final isoMatch = _iso.firstMatch(value);
    if (isoMatch != null) {
      return _build(
        year: int.parse(isoMatch.group(1)!),
        month: int.parse(isoMatch.group(2)!),
        day: int.parse(isoMatch.group(3)!),
        hour: isoMatch.group(4),
        minute: isoMatch.group(5),
        second: isoMatch.group(6),
      );
    }

    final dayFirstMatch = _dayFirst.firstMatch(value);
    if (dayFirstMatch != null) {
      var year = int.parse(dayFirstMatch.group(3)!);
      if (year < 100) year += 2000;
      return _build(
        year: year,
        month: int.parse(dayFirstMatch.group(2)!),
        day: int.parse(dayFirstMatch.group(1)!),
        hour: dayFirstMatch.group(4),
        minute: dayFirstMatch.group(5),
        second: dayFirstMatch.group(6),
      );
    }

    return null;
  }

  static DateTime? _build({
    required int year,
    required int month,
    required int day,
    String? hour,
    String? minute,
    String? second,
  }) {
    if (month < 1 || month > 12) return null;
    if (day < 1 || day > 31) return null;
    final h = hour != null ? int.parse(hour) : 0;
    final mi = minute != null ? int.parse(minute) : 0;
    final se = second != null ? int.parse(second) : 0;
    if (h > 23 || mi > 59 || se > 59) return null;

    final result = DateTime(year, month, day, h, mi, se);
    // DateTime silently rolls an out-of-range day into the next month
    // (e.g. Feb 31 -> Mar 3) — reject that instead of accepting a
    // fabricated date.
    if (result.month != month || result.day != day) return null;
    return result;
  }
}
