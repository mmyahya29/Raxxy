import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:vibration/vibration.dart';
import 'dart:io'; // ADD THIS for Platform check
import 'package:flutter/foundation.dart'; // ADD THIS for debugPrint

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
  debugPrint('📬 Sending Notification: $title - $body');

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
    debugPrint('✅ Notification shown successfully');
  } catch (e) {
    debugPrint('❌ Error showing notification: $e');
  }
}

class CoachingService {
  // Singleton pattern for easy access
  static final CoachingService _instance = CoachingService._internal();
  factory CoachingService() => _instance;
  CoachingService._internal(); // REMOVED _initTts() call from here

  final FlutterTts _tts = FlutterTts();
  DateTime? _lastFeedbackTime;
  bool _isInitialized = false; // Track initialization state

  // Cooldown duration to prevent spamming
  final Duration _cooldown = const Duration(seconds: 4);

  /// Initialize TTS with proper Android configuration
  Future<void> _initTts() async {
    if (_isInitialized) {
      debugPrint('⚠️ TTS already initialized, skipping...');
      return;
    }

    debugPrint('🔊 Initializing TTS engine...');

    try {
      // Set up completion handlers BEFORE configuring
      _tts.setStartHandler(() {
        debugPrint('🎤 TTS: Speech started');
      });

      _tts.setCompletionHandler(() {
        debugPrint('✅ TTS: Speech completed');
      });

      _tts.setErrorHandler((msg) {
        debugPrint('❌ TTS Error: $msg');
      });

      _tts.setCancelHandler(() {
        debugPrint('⏹️ TTS: Speech cancelled');
      });

      // Basic TTS configuration
      await _tts.setLanguage("en-US");
      await _tts.setSpeechRate(0.5); // Natural speaking speed
      await _tts.setVolume(1.0); // Max volume
      await _tts.setPitch(1.0); // Normal pitch

      // Platform-specific configuration
      if (Platform.isAndroid) {
        debugPrint('🤖 Applying Android-specific TTS settings...');

        // Wait for speech to complete before returning
        await _tts.awaitSpeakCompletion(true);

        // Use shared TTS instance (better for background apps)
        await _tts.setSharedInstance(true);

        debugPrint('✅ Android TTS settings applied');
      } else if (Platform.isIOS) {
        debugPrint('🍎 Applying iOS-specific TTS settings...');
        await _tts.setSharedInstance(true);
        await _tts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          [
            IosTextToSpeechAudioCategoryOptions.allowBluetooth,
            IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
            IosTextToSpeechAudioCategoryOptions.mixWithOthers,
          ],
          IosTextToSpeechAudioMode.defaultMode,
        );
      }

      // Verify TTS is working by checking available languages
      final languages = await _tts.getLanguages;
      if (languages != null && languages.isNotEmpty) {
        debugPrint('✅ TTS initialized successfully');
        debugPrint('   Available languages: ${languages.length}');
        debugPrint('   Using language: en-US');
        _isInitialized = true;
      } else {
        debugPrint('⚠️ TTS initialized but no languages available');
        _isInitialized = true; // Still mark as initialized to prevent loops
      }
    } catch (e) {
      debugPrint('❌ Failed to initialize TTS: $e');
      _isInitialized = true; // Prevent infinite retry loops
    }
  }

  /// Triggers haptic and vocal feedback with cooldown check
  Future<void> triggerFeedback({
    required String message,
    required List<int> vibrationPattern
  }) async {
    debugPrint('');
    debugPrint('═══════════════════════════════════════');
    debugPrint('🔔 Feedback Triggered');
    debugPrint('   Message: "$message"');
    debugPrint('   Vibration pattern: $vibrationPattern');

    // Initialize TTS on first use (lazy initialization)
    if (!_isInitialized) {
      debugPrint('   TTS not initialized, initializing now...');
      await _initTts();
    }

    final now = DateTime.now();

    // Check cooldown period
    if (_lastFeedbackTime != null) {
      final timeSinceLastFeedback = now.difference(_lastFeedbackTime!);
      if (timeSinceLastFeedback <= _cooldown) {
        final remainingCooldown = _cooldown - timeSinceLastFeedback;
        debugPrint('⏳ Feedback blocked by cooldown');
        debugPrint('   ${remainingCooldown.inSeconds}s remaining');
        debugPrint('═══════════════════════════════════════');
        return;
      }
    }

    // Update cooldown timer
    _lastFeedbackTime = now;

    try {
      // 1. Trigger Haptics
      debugPrint('📳 Triggering haptics...');
      if (await Vibration.hasVibrator() ?? false) {
        Vibration.vibrate(pattern: vibrationPattern);
        debugPrint('✅ Haptics triggered successfully');
      } else {
        debugPrint('⚠️ Device has no vibrator');
      }

      // 2. Trigger Voice
      debugPrint('🔊 Triggering TTS...');

      // Stop any ongoing speech first
      await _tts.stop();

      // Speak the message
      var result = await _tts.speak(message);

      if (result == 1) {
        debugPrint('✅ TTS speak() initiated successfully');
      } else {
        debugPrint('⚠️ TTS speak() returned unexpected result: $result');
      }

      debugPrint("📢 Coaching Feedback Delivered: '$message'");

    } catch (e) {
      debugPrint('❌ Error during feedback delivery: $e');
    }

    debugPrint('═══════════════════════════════════════');
    debugPrint('');
  }

  /// Manually stop TTS (useful for cleanup)
  Future<void> stop() async {
    await _tts.stop();
    debugPrint('🛑 TTS stopped manually');
  }

  /// Dispose method for cleanup (call when service is destroyed)
  void dispose() {
    _tts.stop();
    debugPrint('🗑️ CoachingService disposed');
  }
}