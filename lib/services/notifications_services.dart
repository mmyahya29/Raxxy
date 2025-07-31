import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

final FlutterLocalNotificationsPlugin notificationsPlugin = FlutterLocalNotificationsPlugin();

Future<void> initNotifications() async {
  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings =
  InitializationSettings(android: initializationSettingsAndroid);

  await notificationsPlugin.initialize(initializationSettings);

  if (await Permission.notification.isDenied) {
    await Permission.notification.request();
  }
}

Future<void> sendNotification(String title, String body) async {
  print('Sending Notification: $title - $body');

  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'vehicle_channel',
    'Vehicle Monitoring',
    channelDescription: 'Notifications about vehicle acceleration and braking',
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
  );

  const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

  try {
    await notificationsPlugin.show(
      0,
      title,
      body,
      platformDetails,
    );
  } catch (e) {
    print('Error showing notification: $e');
  }
}