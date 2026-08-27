import 'package:hive/hive.dart';
import 'package:paysense/shared/models/goal.dart';
import 'package:paysense/shared/services/account_scope.dart';

class GoalRepository {
  GoalRepository._();

  static final GoalRepository instance = GoalRepository._();

  static const String _boxName = 'goals';

  Box<Goal> get _box =>
      Hive.box<Goal>(AccountScope.instance.scopedBoxName(_boxName));

  Future<List<Goal>> getAll() async {
    return List<Goal>.unmodifiable(_box.values.toList());
  }

  Future<Goal?> getById(String id) async {
    return _box.get(id);
  }

  Future<void> add(Goal goal) async {
    await _box.put(goal.id, goal);
  }

  Future<void> update(Goal goal) async {
    if (_box.containsKey(goal.id)) {
      await _box.put(goal.id, goal);
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
