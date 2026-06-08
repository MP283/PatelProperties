import 'dart:js_interop';

@JS('Notification.permission')
external String get notificationPermission;

extension type _Notification._(JSObject _) implements JSObject {
  external factory _Notification(String title, _NotificationOptions options);
}

extension type _NotificationOptions._(JSObject _) implements JSObject {
  external factory _NotificationOptions({String body});
}

void showBrowserNotification(String title, String body) {
  try {
    if (notificationPermission == 'granted') {
      _Notification(title, _NotificationOptions(body: body));
    }
    // If not granted, silently skip — iOS Safari doesn't support web notifications
  } catch (e) {
    // Silently ignore — never crash the app over a notification
  }
}