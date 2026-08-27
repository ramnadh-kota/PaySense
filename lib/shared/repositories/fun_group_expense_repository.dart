import 'package:hive/hive.dart';

import '../models/fun_group_expense.dart';
import '../services/account_scope.dart';

/// Account-scoped storage for Fun Funds group/shared expenses — local only,
/// never a payment gateway, never shared off-device.
class FunGroupExpenseRepository {
  FunGroupExpenseRepository._();

  static final FunGroupExpenseRepository instance =
      FunGroupExpenseRepository._();

  static const String _boxName = 'fun_group_expenses';

  Box<FunGroupExpense> get _box => Hive.box<FunGroupExpense>(
    AccountScope.instance.scopedBoxName(_boxName),
  );

  Future<List<FunGroupExpense>> getAll() async {
    final all = _box.values.toList()..sort((a, b) => b.date.compareTo(a.date));
    return List<FunGroupExpense>.unmodifiable(all);
  }

  Future<FunGroupExpense?> getById(String id) async {
    return _box.get(id);
  }

  Future<void> add(FunGroupExpense expense) async {
    await _box.put(expense.id, expense);
  }

  Future<void> update(FunGroupExpense expense) async {
    if (_box.containsKey(expense.id)) {
      await _box.put(expense.id, expense);
    }
  }

  Future<bool> delete(String id) async {
    if (!_box.containsKey(id)) {
      return false;
    }
    await _box.delete(id);
    return true;
  }
}
