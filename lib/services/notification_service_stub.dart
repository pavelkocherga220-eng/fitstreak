import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:flutter/material.dart';

final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

Future<void> initNotifications() async {
  try {
    // Инициализация часовых поясов
    tz.initializeTimeZones();
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
      // Запрашиваем разрешение на уведомления (Android 13+)
      await androidImplementation.requestNotificationsPermission();

      // Создаем канал для уведомлений
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'fitstreak_channel',
        'FitStreak Reminders',
        description: 'Напоминания о тренировках',
        importance: Importance.max,
        playSound: true,
      );
      await androidImplementation.createNotificationChannel(channel);
    }
  } catch (e) {
    debugPrint('Ошибка инициализации уведомлений: $e');
  }
}

// Для сиюминутных показов используем id 999, чтобы не затирать запланированные (они под id 0..N)
void showNotification(String title, String body) async {
  try {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'fitstreak_channel',
      'FitStreak Reminders',
      channelDescription: 'Напоминания о тренировках',
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);
    
    await _localNotifications.show(999, title, body, platformDetails);
  } catch (e) {
    debugPrint('Ошибка показа уведомления: $e');
  }
}

Future<void> scheduleReminders(List<TimeOfDay> times) async {
  try {
    // Отменяем старые запланированные уведомления
    await _localNotifications.cancelAll();

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        
    // Проверяем, разрешил ли пользователь точные будильники (Android 12+)
    bool canExact = false;
    if (androidPlugin != null) {
      try {
        canExact = await androidPlugin.canScheduleExactNotifications() ?? false;
      } catch (e) {
        debugPrint('Ошибка проверки точных будильников: $e');
      }
    }

    // Если точные разрешены — используем их, иначе — неточные (система сама разбудит телефон)
    final scheduleMode = canExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    for (int i = 0; i < times.length; i++) {
      final time = times[i];
      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, time.hour, time.minute,
      );
      
      // Если время уже прошло сегодня, планируем на завтра
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
        androidScheduleMode: scheduleMode,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time, // Повторять ежедневно
      );
      debugPrint('Запланировано уведомление #$i на ${time.hour}:${time.minute} ($scheduleMode)');
    }
  } catch (e) {
    debugPrint('Ошибка планирования уведомлений: $e');
  }
}