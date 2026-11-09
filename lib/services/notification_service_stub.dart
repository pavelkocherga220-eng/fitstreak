import 'package:flutter/foundation.dart'; // <-- ДОБАВИТЬ ИМПОРТ
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

Future<void> initNotifications() async {
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

  await _localNotifications.show(
    0,
    title,
    body,
    platformDetails,
  );
  
  debugPrint('Команда показа уведомления выполнена!');
}