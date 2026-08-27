import 'package:hive/hive.dart';

import '../models/sms_review_item.dart';
import '../services/account_scope.dart';

class SmsReviewRepository {
  SmsReviewRepository._();

  static final SmsReviewRepository instance = SmsReviewRepository._();

  static const String _boxName = 'sms_review_items';

  Box<SmsReviewItem> get _box =>
      Hive.box<SmsReviewItem>(AccountScope.instance.scopedBoxName(_boxName));

  Future<List<SmsReviewItem>> getAll() async {
    final all = _box.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List<SmsReviewItem>.unmodifiable(all);
  }

  Future<List<SmsReviewItem>> getPending() async {
    final all = await getAll();
    return all.where((item) => item.status == SmsReviewStatus.pending).toList();
  }

  Future<SmsReviewItem?> getById(String id) async {
    return _box.get(id);
  }

  /// Inserts [item] only if no review item with the same [SmsReviewItem.id]
  /// (the SMS's fingerprint) already exists — the SAME underlying SMS must
  /// never be surfaced for review twice. Returns true if actually inserted.
  Future<bool> addIfNotExists(SmsReviewItem item) async {
    if (_box.containsKey(item.id)) {
      return false;
    }
    await _box.put(item.id, item);
    return true;
  }

  Future<void> update(SmsReviewItem item) async {
    await _box.put(item.id, item);
  }

  Future<void> delete(String id) async {
    await _box.delete(id);
  }
}
