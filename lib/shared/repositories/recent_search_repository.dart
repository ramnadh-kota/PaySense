import 'package:hive/hive.dart';

/// PAYSENSE SEARCH — persists the user's recent search queries (text
/// only, never search RESULTS/financial data) so the empty-query state
/// can show "Recent searches". Mirrors `SmsFingerprintRepository`'s
/// untyped-box-of-a-list pattern, capped like that repository is.
class RecentSearchRepository {
  RecentSearchRepository._();

  static final RecentSearchRepository instance = RecentSearchRepository._();

  static const _boxName = 'recent_searches';
  static const _key = 'queries';
  static const _maxEntries = 10;

  Future<Box> _box() async {
    if (Hive.isBoxOpen(_boxName)) return Hive.box(_boxName);
    return Hive.openBox(_boxName);
  }

  Future<List<String>> getRecent() async {
    final box = await _box();
    final raw = box.get(_key) as List?;
    return raw?.cast<String>() ?? const [];
  }

  Future<void> record(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    final box = await _box();
    final current = List<String>.of(await getRecent());
    current.removeWhere((q) => q.toLowerCase() == trimmed.toLowerCase());
    current.insert(0, trimmed);
    await box.put(_key, current.take(_maxEntries).toList());
  }

  Future<void> clear() async {
    final box = await _box();
    await box.delete(_key);
  }
}
