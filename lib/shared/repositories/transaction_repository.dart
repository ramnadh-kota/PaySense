import 'package:hive/hive.dart';
import 'package:paysense/shared/models/transaction.dart';

class TransactionRepository {
  TransactionRepository._();

  static final TransactionRepository instance = TransactionRepository._();

  static const String _boxName = 'transactions';

  Box<Transaction> get _box => Hive.box<Transaction>(_boxName);

  Future<List<Transaction>> getAll() async {
    return List<Transaction>.unmodifiable(_box.values.toList());
  }

  Future<Transaction?> getById(String id) async {
    return _box.get(id);
  }

  Future<void> add(Transaction transaction) async {
    if (!_box.containsKey(transaction.id)) {
      await _box.put(transaction.id, transaction);
    }
  }

  Future<void> update(Transaction transaction) async {
    if (_box.containsKey(transaction.id)) {
      await _box.put(transaction.id, transaction);
    }
  }

  Future<void> delete(String id) async {
    await _box.delete(id);
  }
}
