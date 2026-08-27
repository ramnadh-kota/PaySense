import 'package:hive/hive.dart';
import 'package:paysense/shared/models/loan.dart';
import 'package:paysense/shared/services/account_scope.dart';

class LoanRepository {
  LoanRepository._();

  static final LoanRepository instance = LoanRepository._();

  static const String _boxName = 'loans';

  Box<Loan> get _box =>
      Hive.box<Loan>(AccountScope.instance.scopedBoxName(_boxName));

  Future<List<Loan>> getAll() async {
    return List<Loan>.unmodifiable(_box.values.toList());
  }

  Future<Loan?> getById(String id) async {
    return _box.get(id);
  }

  Future<void> add(Loan loan) async {
    await _box.put(loan.id, loan);
  }

  Future<void> update(Loan loan) async {
    if (_box.containsKey(loan.id)) {
      await _box.put(loan.id, loan);
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
