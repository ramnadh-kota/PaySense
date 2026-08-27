import 'package:hive/hive.dart';

import '../models/notification_record.dart';
import '../services/account_scope.dart';

class NotificationRepository {
  NotificationRepository._();

  static final NotificationRepository instance = NotificationRepository._();

  static const String _boxName = 'app_notifications';

  Box<AppNotification> get _box => Hive.box<AppNotification>(
    AccountScope.instance.scopedBoxName(_boxName),
  );

  Future<List<AppNotification>> getAll() async {
    final all = _box.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List<AppNotification>.unmodifiable(all);
  }

  Future<void> add(AppNotification notification) async {
    await _box.put(notification.id, notification);
  }

  /// Inserts [notification] only if no record with the same [id] already
  /// exists — the idempotency mechanism that keeps rescheduling an existing
  /// reminder (bill/recurring/loan) from creating duplicate history entries.
  /// Returns true if it was actually inserted.
  Future<bool> addIfNotExists(AppNotification notification) async {
    if (_box.containsKey(notification.id)) {
      return false;
    }
    await _box.put(notification.id, notification);
    return true;
  }

  Future<void> markAsRead(String id) async {
    final existing = _box.get(id);
    if (existing == null || existing.isRead) {
      return;
    }
    await _box.put(id, existing.copyWith(isRead: true));
  }

  Future<void> markAllAsRead() async {
    for (final notification in _box.values) {
      if (!notification.isRead) {
        await _box.put(notification.id, notification.copyWith(isRead: true));
      }
    }
  }

  Future<void> delete(String id) async {
    await _box.delete(id);
  }

  Future<void> clearAll() async {
    await _box.clear();
  }

  Future<int> unreadCount() async {
    return _box.values.where((n) => !n.isRead).length;
  }
}
