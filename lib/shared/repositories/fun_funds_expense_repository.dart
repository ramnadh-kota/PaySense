import 'package:hive/hive.dart';

import '../models/fun_funds_expense.dart';

/// Persists [FunFundsExpense]s. See `FunFundsGroupRepository`'s doc
/// comment for the untyped-box pattern this mirrors.
class FunFundsExpenseRepository {
  FunFundsExpenseRepository._();

  static final FunFundsExpenseRepository instance = FunFundsExpenseRepository._();

  static const String boxName = 'fun_funds_expenses';

  Future<Box> _box() async {
    if (Hive.isBoxOpen(boxName)) return Hive.box(boxName);
    return Hive.openBox(boxName);
  }

  Future<List<FunFundsExpense>> getAll() async {
    final box = await _box();
    return box.values
        .map((raw) => FunFundsExpense.fromMap(Map<String, dynamic>.from(raw as Map)))
        .toList();
  }

  Future<List<FunFundsExpense>> getForGroup(String groupId) async {
    final all = await getAll();
    return all.where((e) => e.groupId == groupId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> upsert(FunFundsExpense expense) async {
    final box = await _box();
    await box.put(expense.id, expense.toMap());
  }

  Future<void> delete(String id) async {
    final box = await _box();
    await box.delete(id);
  }

  /// Removes every expense belonging to [groupId] — used when a group
  /// itself is deleted, so no orphaned expenses remain.
  Future<void> deleteForGroup(String groupId) async {
    final expenses = await getForGroup(groupId);
    final box = await _box();
    for (final expense in expenses) {
      await box.delete(expense.id);
    }
  }

  Future<void> clearAll() async {
    final box = await _box();
    await box.clear();
  }
}
