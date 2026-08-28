import 'package:hive/hive.dart';

import '../models/fun_funds_group.dart';

/// Persists [FunFundsGroup]s. Mirrors
/// `AccountAggregatorConnectionRepository`'s untyped-box +
/// `toMap()`/`fromMap()` pattern — see that file's doc comment for why.
class FunFundsGroupRepository {
  FunFundsGroupRepository._();

  static final FunFundsGroupRepository instance = FunFundsGroupRepository._();

  static const String boxName = 'fun_funds_groups';

  Future<Box> _box() async {
    if (Hive.isBoxOpen(boxName)) return Hive.box(boxName);
    return Hive.openBox(boxName);
  }

  Future<List<FunFundsGroup>> getAll() async {
    final box = await _box();
    return box.values
        .map((raw) => FunFundsGroup.fromMap(Map<String, dynamic>.from(raw as Map)))
        .toList();
  }

  Future<FunFundsGroup?> getById(String id) async {
    final box = await _box();
    final raw = box.get(id);
    if (raw == null) return null;
    return FunFundsGroup.fromMap(Map<String, dynamic>.from(raw as Map));
  }

  Future<void> upsert(FunFundsGroup group) async {
    final box = await _box();
    await box.put(group.id, group.toMap());
  }

  Future<void> delete(String id) async {
    final box = await _box();
    await box.delete(id);
  }

  Future<void> clearAll() async {
    final box = await _box();
    await box.clear();
  }
}
