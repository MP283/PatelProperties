import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:patel_properties/notification_service.dart';
import 'firebase_options.dart';
import 'screens/login_page.dart';
import 'screens/dashboard.dart';

import 'web_notification_stub.dart'
    if (dart.library.html) 'web_notification.dart';

const String _vapidKey =
    'BC96x3XyR5k4GOKP2oTHl0fF0xyrxhOzEIJxCJDpwa2fP9mzsL4e4G-WC8zWeUfHC9wx1FdgugLv23vx6KYBASo';

// ✅ Save token to Firestore — called after user is confirmed logged in
Future<void> saveTokenToFirestore() async {
  final messaging = FirebaseMessaging.instance;
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  try {
    if (kIsWeb) {
      final token = await messaging.getToken(vapidKey: _vapidKey);
      if (token != null) {
        await FirebaseFirestore.instance
            .collection('fcm_tokens')
            .doc(token)
            .set({
          'token': token,
          'platform': 'web',
          'uid': user.uid,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        debugPrint('✅ Web token saved: $token');
      }
    } else {
      final token = await messaging.getToken();
      if (token != null) {
        await FirebaseFirestore.instance
            .collection('fcm_tokens')
            .doc(token)
            .set({
          'token': token,
          'platform': 'android',
          'uid': user.uid,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        debugPrint('✅ Android token saved: $token');
      }
    }
  } catch (e) {
    debugPrint('❌ Token save error: $e');
  }
}

Future<void> setupFCM() async {
  final messaging = FirebaseMessaging.instance;

  final settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  debugPrint('🔔 FCM permission: ${settings.authorizationStatus}');

  if (kIsWeb) {
    // ✅ Show confirmation notification on web
    try {
      final token = await messaging.getToken(vapidKey: _vapidKey);
      debugPrint('✅ FCM Web Token obtained: $token');

      showBrowserNotification(
        '✅ Notifications Active',
        'Patel Properties will now alert you of new entries.',
      );
    } catch (e) {
      debugPrint('❌ FCM web token error: $e');
    }

    // ✅ Foreground messages on web
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('📨 Foreground message: ${message.notification?.title}');
      if (message.notification != null) {
        showBrowserNotification(
          message.notification!.title ?? 'New Entry',
          message.notification!.body ?? '',
        );
      }
    });

    return;
  }

  // ✅ Native (Android/iOS)
  NotificationService.initialize();

  // ✅ Foreground messages on Android
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    if (message.notification != null) {
      NotificationService.showNotification(
        message.notification!.title ?? 'New Entry',
        message.notification!.body ?? '',
      );
    }
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await setupFCM();
  runApp(const RealEstateApp());
}

class RealEstateApp extends StatelessWidget {
  const RealEstateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Patel Properties',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasData) {
            // ✅ User is logged in — now save the FCM token
            saveTokenToFirestore();
            return const DashboardPage();
          }
          return const LoginPage();
        },
      ),
    );
  }
}