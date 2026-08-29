import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _timezoneReady = false;

  static const String _channelId = 'recurring_payments';
  static const String _channelName = 'Upcoming Payments';
  static const String _channelDescription = 'Reminders for upcoming recurring income and expenses';

  static const String proactiveChannelId = 'paysense_proactive_awareness';
  static const String proactiveChannelName = 'Money Awareness & Insights';
  static const String proactiveChannelDescription =
      'Proactive, calm reminders for Daily Check-In, Safe-to-Spend, and important money insights';

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
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings();
      const settings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
        macOS: iosSettings,
      );
      await _plugin.initialize(settings: settings);

      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            proactiveChannelId,
            proactiveChannelName,
            description: proactiveChannelDescription,
            importance: Importance.high,
          ),
        );
      }
    } catch (error) {
      debugPrint('NotificationService: initialize failed: $error');
    }
  }

  Future<bool> requestNotificationsPermission() async {
    try {
      final androidRes = await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();

      final iosRes = await _plugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);

      return androidRes ?? iosRes ?? false;
    } catch (error) {
      debugPrint('NotificationService: requestNotificationsPermission failed: $error');
      return false;
    }
  }

  Future<void> showImmediateNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    String channelId = proactiveChannelId,
  }) async {
    try {
      final androidDetails = AndroidNotificationDetails(
        channelId,
        channelId == proactiveChannelId ? proactiveChannelName : _channelName,
        channelDescription:
            channelId == proactiveChannelId ? proactiveChannelDescription : _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
      );
      final details = NotificationDetails(
        android: androidDetails,
        iOS: const DarwinNotificationDetails(),
        macOS: const DarwinNotificationDetails(),
      );

      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: details,
        payload: payload,
      );
    } catch (error) {
      debugPrint('NotificationService: showImmediateNotification failed: $error');
    }
  }

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
