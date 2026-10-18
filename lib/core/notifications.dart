import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Thin wrapper over local notifications for reminders and pushed alerts.
class Notifications {
  static final _plugin = FlutterLocalNotificationsPlugin();

  /// Partner pushes from the Cloud Functions use this channel too
  /// (functions/index.js), so they pop up on screen like a chat message.
  static const channelId = 'goodnight_general';

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      channelId,
      'GoodNight',
      channelDescription: 'Bedtime reminders and alerts from your partner',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  static Future<void> init() async {
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // Falls back to UTC; reminders would be off, so this should be rare.
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_notification'),
      ),
    );
    // Create the channel up front: a push that arrives before any local
    // notification was shown would otherwise land on Firebase's quiet
    // fallback channel.
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            channelId,
            'GoodNight',
            description: 'Bedtime reminders and alerts from your partner',
            importance: Importance.high,
          ),
        );
  }

  static Future<void> showNow(int id, String title, String body) =>
      _plugin.show(id: id, title: title, body: body, notificationDetails: _details);

  /// Repeats every day at [minuteOfDay] (minutes since local midnight).
  static Future<void> scheduleDaily({
    required int id,
    required int minuteOfDay,
    required String title,
    required String body,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var when = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      minuteOfDay ~/ 60,
      minuteOfDay % 60,
    );
    if (!when.isAfter(now)) when = when.add(const Duration(days: 1));
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: when,
      notificationDetails: _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static Future<void> cancel(int id) => _plugin.cancel(id: id);

  static Future<void> cancelAll() => _plugin.cancelAll();
}
