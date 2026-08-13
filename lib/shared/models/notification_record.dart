import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

part 'notification_record.g.dart';

enum NotificationType {
  bill,
  recurringPayment,
  loanPayment,
  goal,
  financialHealth,
  general,
}

extension NotificationTypeX on NotificationType {
  static NotificationType fromKey(String key) {
    return NotificationType.values.firstWhere(
      (t) => t.name == key,
      orElse: () => NotificationType.general,
    );
  }
}

/// A lightweight in-app notification history record — metadata only. Never
/// holds authentication data or a duplicate copy of the underlying financial
/// record; [relatedRoute] is just an existing [AppRoutes] constant to
/// navigate to when tapped.
@immutable
@HiveType(typeId: 9)
class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.createdAt,
    this.isRead = false,
    this.relatedRoute,
  });

  /// Stable, caller-chosen identifier (not a random uuid) so re-scheduling
  /// the same underlying reminder doesn't create a duplicate history entry.
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String message;

  @HiveField(3)
  final String type;

  @HiveField(4)
  final DateTime createdAt;

  @HiveField(5)
  final bool isRead;

  @HiveField(6)
  final String? relatedRoute;

  NotificationType get notificationType => NotificationTypeX.fromKey(type);

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      title: title,
      message: message,
      type: type,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
      relatedRoute: relatedRoute,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is AppNotification &&
        other.id == id &&
        other.title == title &&
        other.message == message &&
        other.type == type &&
        other.createdAt == createdAt &&
        other.isRead == isRead &&
        other.relatedRoute == relatedRoute;
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    message,
    type,
    createdAt,
    isRead,
    relatedRoute,
  );
}
