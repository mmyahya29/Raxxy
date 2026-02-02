import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:vibration/vibration.dart';

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

class CoachingService {
  // Singleton pattern for easy access
  static final CoachingService _instance = CoachingService._internal();
  factory CoachingService() => _instance;
  CoachingService._internal() {
    _initTts();
  }

  final FlutterTts _tts = FlutterTts();
  DateTime? _lastFeedbackTime;

  // Cooldown duration to prevent spamming
  final Duration _cooldown = const Duration(seconds: 4);

  void _initTts() async {
    // Basic setup
    await _tts.setLanguage("en-US");
    await _tts.setSpeechRate(0.5); // 0.5 is usually a good natural speed
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
  }

  /// Triggers haptic and vocal feedback with a cooldown check
  Future<void> triggerFeedback({
    required String message,
    required List<int> vibrationPattern
  }) async {
    final now = DateTime.now();

    // Check if we are in the cooldown period
    if (_lastFeedbackTime == null ||
        now.difference(_lastFeedbackTime!) > _cooldown) {

      _lastFeedbackTime = now;

      // 1. Trigger Haptics
      if (await Vibration.hasVibrator() ?? false) {
        // pattern: [wait, vibrate, wait, vibrate...]
        Vibration.vibrate(pattern: vibrationPattern);
      }

      // 2. Trigger Voice
      // Stop any current speech to ensure the newest warning is heard
      await _tts.stop();
      await _tts.speak(message);

      print("📢 Coaching Feedback: '$message'");
    }
  }
}