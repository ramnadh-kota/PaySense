import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/notification_record.dart';
import '../repositories/notification_repository.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository.instance;
});

final notificationsProvider =
    AsyncNotifierProvider<NotificationsNotifier, List<AppNotification>>(
      NotificationsNotifier.new,
    );

/// Count of unread notifications, 0 while loading/on error so the Dashboard
/// bell never shows a stale or crashing badge.
final unreadNotificationCountProvider = Provider<int>((ref) {
  final notifications = ref.watch(notificationsProvider).value ?? const [];
  return notifications.where((n) => !n.isRead).length;
});

class NotificationsNotifier extends AsyncNotifier<List<AppNotification>> {
  @override
  Future<List<AppNotification>> build() async {
    final repository = ref.read(notificationRepositoryProvider);
    return repository.getAll();
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    final repository = ref.read(notificationRepositoryProvider);
    state = await AsyncValue.guard(() => repository.getAll());
  }

  /// Adds [notification] only if no record with the same id already exists.
  /// This is the entry point every reminder-scheduling call site should use
  /// so re-scheduling an existing reminder never creates a duplicate.
  Future<void> addIfNotExists(AppNotification notification) async {
    final repository = ref.read(notificationRepositoryProvider);
    final inserted = await repository.addIfNotExists(notification);
    if (inserted) {
      state = await AsyncValue.guard(() => repository.getAll());
    }
  }

  Future<void> markAsRead(String id) async {
    final repository = ref.read(notificationRepositoryProvider);
    await repository.markAsRead(id);
    state = await AsyncValue.guard(() => repository.getAll());
  }

  Future<void> markAllAsRead() async {
    final repository = ref.read(notificationRepositoryProvider);
    await repository.markAllAsRead();
    state = await AsyncValue.guard(() => repository.getAll());
  }

  Future<void> delete(String id) async {
    final repository = ref.read(notificationRepositoryProvider);
    await repository.delete(id);
    state = await AsyncValue.guard(() => repository.getAll());
  }

  Future<void> clearAll() async {
    final repository = ref.read(notificationRepositoryProvider);
    await repository.clearAll();
    state = await AsyncValue.guard(() => repository.getAll());
  }
}
