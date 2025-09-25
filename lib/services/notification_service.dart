// lib/services/notification_service.dart
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'task_channel',
    'Tasks',
    description: 'Task reminders',
    importance: Importance.max,
  );

  static Future<void> init() async {
    tz.initializeTimeZones();

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );

    await _plugin.initialize(initSettings);

    final android =
    _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(_channel);
    await android?.requestNotificationsPermission();
  }

  static NotificationDetails get _details => NotificationDetails(
    android: AndroidNotificationDetails(
      _channel.id,
      _channel.name,
      channelDescription: _channel.description,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      visibility: NotificationVisibility.public,
    ),
    iOS: const DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
      presentBadge: true,
    ),
  );

  static Future<void> scheduleNotification(
      int id,
      String title,
      String body,
      DateTime when, {
        int recurrence = 0, // 0 = none, 1 = daily, 2 = weekly
        bool exact = false,
      }) async {
    final now = DateTime.now();
    if (when.isBefore(now)) {
      when = now.add(const Duration(seconds: 15));
    }

    final tzDateTime = tz.TZDateTime.from(when, tz.local);
    final mode = exact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    try {
      if (recurrence == 1) {
        // daily
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          tzDateTime,
          _details,
          androidScheduleMode: mode,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: 'task:$id',
        );
      } else if (recurrence == 2) {
        // weekly
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          tzDateTime,
          _details,
          androidScheduleMode: mode,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          payload: 'task:$id',
        );
      } else {
        // one-time
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          tzDateTime,
          _details,
          androidScheduleMode: mode,
          matchDateTimeComponents: null,
          payload: 'task:$id',
        );
      }
    } on PlatformException catch (e) {
      if (e.code == 'exact_alarms_not_permitted' && exact) {
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          tzDateTime,
          _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: null,
          payload: 'task:$id',
        );
      } else {
        rethrow;
      }
    }
  }

  static Future<void> cancelNotification(int id) => _plugin.cancel(id);

  static Future<void> requestExactAlarmPermission() async {
    final android =
    _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestExactAlarmsPermission();
  }
}
