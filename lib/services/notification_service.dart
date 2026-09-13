import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Dumb local daily reminder — purely local scheduling, no network logic.
/// Tapping the notification opens the app, which triggers the Smart Pull.
class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const int _reminderId = 1;
  static const String _channelId = 'daily_reminder';
  static const String _channelName = 'Daily reminder';

  /// Initializes the plugin, requests the Android 13+ notification runtime
  /// permission, and schedules the daily 07:00 reminder.
  static Future<void> init() async {
    try {
      // Android: default launcher icon, no custom drawable required.
      const androidInit = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const initSettings = InitializationSettings(
        android: androidInit,
      );
      await _plugin.initialize(settings: initSettings);

      // Android 13+ requires a runtime permission for notifications.
      final androidImpl = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (androidImpl != null) {
        final granted = await androidImpl.requestNotificationsPermission();
        debugPrint('NotifyFlow: POST_NOTIFICATIONS granted=$granted');
      }

      _scheduleDailyReminder();
    } catch (e, st) {
      // Never block app startup because notifications failed.
      debugPrint('NotifyFlow: init failed: $e\n$st');
    }
  }

  /// Schedules a repeating notification every day at 07:00 local time.
  /// [DateTimeComponents.time] makes the plugin reschedule for the next day
  /// automatically after each fire.
  static Future<void> _scheduleDailyReminder() async {
    tzdata.initializeTimeZones();
    final now = DateTime.now();
    var next7am = tz.TZDateTime.from(
      DateTime(now.year, now.month, now.day, 7),
      tz.local,
    );
    if (!next7am.isAfter(tz.TZDateTime.from(now, tz.local))) {
      // Already past 07:00 today — schedule for tomorrow.
      next7am = next7am.add(const Duration(days: 1));
    }

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Daily nudge to review work status',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);

    await _plugin.zonedSchedule(
      id: _reminderId,
      title: 'Hydra V0',
      body: 'Review your work status before heading to the site.',
      scheduledDate: next7am,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
    debugPrint('NotifyFlow: daily reminder scheduled at $next7am');
  }
}