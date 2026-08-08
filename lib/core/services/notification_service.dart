import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Wraps `flutter_local_notifications` to schedule reminders for upcoming
/// recurring payments. All platform calls are best-effort: failures (e.g.
/// running on a platform/test harness without notification support) are
/// swallowed so the rest of the app keeps working.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _timezoneReady = false;

  static const String _channelId = 'recurring_payments';
  static const String _channelName = 'Upcoming Payments';
  static const String _channelDescription =
      'Reminders for upcoming recurring income and expenses';

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _initialized = true;

    try {
      tz_data.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('UTC'));
      _timezoneReady = true;
    } catch (error) {
      debugPrint('NotificationService: timezone init failed: $error');
    }

    try {
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const iosSettings = DarwinInitializationSettings();
      const settings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
        macOS: iosSettings,
      );
      await _plugin.initialize(settings: settings);

      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();

      await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } catch (error) {
      debugPrint('NotificationService: initialize failed: $error');
    }
  }

  /// Schedules a reminder notification at [scheduledDate]. Does nothing if
  /// the date has already passed or the platform doesn't support scheduling.
  Future<void> scheduleReminder({
    required String id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    if (!_timezoneReady || scheduledDate.isBefore(DateTime.now())) {
      return;
    }

    try {
      const androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
      );
      const details = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
      );

      await _plugin.zonedSchedule(
        id: _notificationIdFor(id),
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.from(scheduledDate, tz.local),
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (error) {
      debugPrint('NotificationService: scheduleReminder failed: $error');
    }
  }

  Future<void> cancelReminder(String id) async {
    try {
      await _plugin.cancel(id: _notificationIdFor(id));
    } catch (error) {
      debugPrint('NotificationService: cancelReminder failed: $error');
    }
  }

  Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (error) {
      debugPrint('NotificationService: cancelAll failed: $error');
    }
  }

  int _notificationIdFor(String id) => id.hashCode & 0x7fffffff;
}
