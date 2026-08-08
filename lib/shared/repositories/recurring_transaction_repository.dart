import 'package:hive/hive.dart';
import 'package:paysense/shared/models/recurring_transaction.dart';

class RecurringTransactionRepository {
  RecurringTransactionRepository._();

  static final RecurringTransactionRepository instance =
      RecurringTransactionRepository._();

  static const String _boxName = 'recurring_transactions';

  Box<RecurringTransaction> get _box =>
      Hive.box<RecurringTransaction>(_boxName);

  Future<List<RecurringTransaction>> getAll() async {
    return List<RecurringTransaction>.unmodifiable(_box.values.toList());
  }

  Future<RecurringTransaction?> getById(String id) async {
    return _box.get(id);
  }

  Future<void> add(RecurringTransaction recurringTransaction) async {
    await _box.put(recurringTransaction.id, recurringTransaction);
  }

  Future<void> update(RecurringTransaction recurringTransaction) async {
    if (_box.containsKey(recurringTransaction.id)) {
      await _box.put(recurringTransaction.id, recurringTransaction);
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
