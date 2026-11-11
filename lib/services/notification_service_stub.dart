import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:flutter/material.dart'; // Для TimeOfDay

final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

Future<void> initNotifications() async {
  tz.initializeTimeZones();
  
  // ИСПРАВЛЕНО: получаем объект TimezoneInfo и берем его identifier
  final timezoneInfo = await FlutterTimezone.getLocalTimezone();
  tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);

  await _localNotifications.initialize(initializationSettings);

  final androidImplementation = _localNotifications
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  if (androidImplementation != null) {
    final bool? granted = await androidImplementation.requestNotificationsPermission();
    debugPrint('Разрешение на уведомления: $granted');

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'fitstreak_channel',
      'FitStreak Reminders',
      description: 'Напоминания о тренировках',
      importance: Importance.max,
      playSound: true,
    );
    await androidImplementation.createNotificationChannel(channel);
  }
}

void showNotification(String title, String body) async {
  debugPrint('Попытка показать уведомление: $title');
  
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'fitstreak_channel',
    'FitStreak Reminders',
    channelDescription: 'Напоминания о тренировках',
    importance: Importance.max,
    priority: Priority.high,
    showWhen: true,
  );

  const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

  await _localNotifications.show(0, title, body, platformDetails);
  debugPrint('Команда показа уведомления выполнена!');
}

Future<void> scheduleReminders(List<TimeOfDay> times) async {
  await _localNotifications.cancelAll(); // отменяем старые

  for (int i = 0; i < times.length; i++) {
    final time = times[i];
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await _localNotifications.zonedSchedule(
      i,
      '🔥 FitStreak',
      'Не забудь про тренировку! Твой стрик ждет.',
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'fitstreak_channel',
          'FitStreak Reminders',
          channelDescription: 'Напоминания о тренировках',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // ежедневно
    );
    debugPrint('Запланировано уведомление на ${time.hour}:${time.minute}');
  }
}