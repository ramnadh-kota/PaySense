import '../models/feature_search_item.dart';

/// FEATURE SEARCH — pure Dart, deterministic, Flutter-independent
/// matching logic (no widget dependency, fully unit-testable). Scores
/// every [FeatureSearchItem] against a query and returns matches ranked
/// best-first; never mutates the registry.
///
/// Matching is deliberately simple substring/alias matching, not a full
/// fuzzy/edit-distance algorithm — "fuzzy-ish" here means: a query
/// matches if it's a substring of the title, a keyword/alias, the
/// category, or the subtitle, case-insensitively, with the highest-value
/// match type ranked first. This is enough to satisfy every example in
/// the spec ("tax" -> Tax Planner, "emi" -> Loans, etc.) without
/// introducing a heavyweight fuzzy-matching dependency.
class FeatureSearchMatcher {
  FeatureSearchMatcher._();

  static List<FeatureSearchItem> search(String query, List<FeatureSearchItem> registry) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return const [];

    final scored = <(int, FeatureSearchItem)>[];
    for (final item in registry) {
      final score = _scoreFor(normalized, item);
      if (score > 0) scored.add((score, item));
    }

    scored.sort((a, b) => b.$1.compareTo(a.$1));
    return scored.map((s) => s.$2).toList();
  }

  /// Higher is better. 0 means no match at all.
  static int _scoreFor(String normalizedQuery, FeatureSearchItem item) {
    final title = item.title.toLowerCase();
    if (title == normalizedQuery) return 100;
    if (title.startsWith(normalizedQuery)) return 90;
    if (title.contains(normalizedQuery)) return 80;

    for (final keyword in item.keywords) {
      final normalizedKeyword = keyword.toLowerCase();
      if (normalizedKeyword == normalizedQuery) return 75;
      if (normalizedKeyword.startsWith(normalizedQuery)) return 65;
      if (normalizedKeyword.contains(normalizedQuery)) return 55;
    }

    if (item.category.toLowerCase().contains(normalizedQuery)) return 30;
    if (item.subtitle.toLowerCase().contains(normalizedQuery)) return 20;

    return 0;
  }
}
