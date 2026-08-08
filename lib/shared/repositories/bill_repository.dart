import 'package:hive/hive.dart';
import 'package:paysense/shared/models/bill.dart';

class BillRepository {
  BillRepository._();

  static final BillRepository instance = BillRepository._();

  static const String _boxName = 'bills';

  Box<Bill> get _box => Hive.box<Bill>(_boxName);

  Future<List<Bill>> getAll() async {
    return List<Bill>.unmodifiable(_box.values.toList());
  }

  Future<Bill?> getById(String id) async {
    return _box.get(id);
  }

  Future<void> add(Bill bill) async {
    await _box.put(bill.id, bill);
  }

  Future<void> update(Bill bill) async {
    if (_box.containsKey(bill.id)) {
      await _box.put(bill.id, bill);
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
