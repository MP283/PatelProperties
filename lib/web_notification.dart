import 'dart:html' as html;

void showBrowserNotification(String title, String body) {
  if (html.Notification.supported) {
    if (html.Notification.permission == 'granted') {
      html.Notification(title, body: body);
    } else {
      html.Notification.requestPermission().then((_) {
        if (html.Notification.permission == 'granted') {
          html.Notification(title, body: body);
        }
      });
    }
  }
}