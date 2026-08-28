import 'package:hive/hive.dart';

import '../models/fun_funds_settlement.dart';

/// Persists [FunFundsSettlement]s. See `FunFundsGroupRepository`'s doc
/// comment for the untyped-box pattern this mirrors.
class FunFundsSettlementRepository {
  FunFundsSettlementRepository._();

  static final FunFundsSettlementRepository instance = FunFundsSettlementRepository._();

  static const String boxName = 'fun_funds_settlements';

  Future<Box> _box() async {
    if (Hive.isBoxOpen(boxName)) return Hive.box(boxName);
    return Hive.openBox(boxName);
  }

  Future<List<FunFundsSettlement>> getAll() async {
    final box = await _box();
    return box.values
        .map((raw) => FunFundsSettlement.fromMap(Map<String, dynamic>.from(raw as Map)))
        .toList();
  }

  Future<List<FunFundsSettlement>> getForGroup(String groupId) async {
    final all = await getAll();
    return all.where((s) => s.groupId == groupId).toList();
  }

  /// Marks one debt (an expense's participant share) settled. Idempotent —
  /// settling an already-settled debt just overwrites the record.
  Future<void> markSettled({
    required String groupId,
    required String expenseId,
    required String debtorName,
    required DateTime settledAt,
  }) async {
    final box = await _box();
    final id = '$expenseId:$debtorName';
    await box.put(
      id,
      FunFundsSettlement(
        id: id,
        groupId: groupId,
        expenseId: expenseId,
        debtorName: debtorName,
        settledAt: settledAt,
      ).toMap(),
    );
  }

  /// Reverses [markSettled] — moves a debt back to Pending.
  Future<void> markPending({required String expenseId, required String debtorName}) async {
    final box = await _box();
    await box.delete('$expenseId:$debtorName');
  }

  /// Removes every settlement belonging to [groupId] — used when a group
  /// itself is deleted.
  Future<void> deleteForGroup(String groupId) async {
    final settlements = await getForGroup(groupId);
    final box = await _box();
    for (final settlement in settlements) {
      await box.delete(settlement.id);
    }
  }

  Future<void> clearAll() async {
    final box = await _box();
    await box.clear();
  }
}
