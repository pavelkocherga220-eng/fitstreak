import 'dart:js_interop';
import 'package:flutter/foundation.dart'; // <-- ДОБАВИТЬ ИМПОРТ

@JS('Notification')
extension type JSNotification._(JSObject _) implements JSObject {
  external factory JSNotification(String title, [JSNotificationOptions options]);
  external static JSPromise<JSString> requestPermission();
  external static String get permission;
}

@JS()
extension type JSNotificationOptions._(JSObject _) implements JSObject {
  external factory JSNotificationOptions({String body});
}

Future<void> initNotifications() async {
  try {
    if (JSNotification.permission == 'default') {
      await JSNotification.requestPermission().toDart;
    }
  } catch (e) {
    debugPrint('Ошибка при запросе разрешения: $e'); // <-- ИСПРАВЛЕНО
  }
}

void showNotification(String title, String body) {
  try {
    if (JSNotification.permission == 'granted') {
      JSNotification(title, JSNotificationOptions(body: body));
    }
  } catch (e) {
    debugPrint('Ошибка при показе уведомления: $e'); // <-- ИСПРАВЛЕНО
  }
}