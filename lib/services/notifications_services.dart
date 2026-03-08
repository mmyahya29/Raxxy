import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:vibration/vibration.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

final FlutterLocalNotificationsPlugin notificationsPlugin =
FlutterLocalNotificationsPlugin();

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

  const NotificationDetails platformDetails =
  NotificationDetails(android: androidDetails);

  try {
    await notificationsPlugin.show(0, title, body, platformDetails);
    debugPrint('✅ Notification shown successfully');
  } catch (e) {
    debugPrint('❌ Error showing notification: $e');
  }
}

class CoachingService {
  static final CoachingService _instance = CoachingService._internal();
  factory CoachingService() => _instance;
  CoachingService._internal();

  final FlutterTts _tts = FlutterTts();
  DateTime? _lastFeedbackTime;
  bool _isInitialized = false;

  // Cooldown duration to prevent feedback spam
  final Duration _cooldown = const Duration(seconds: 4);

  /// Initialize TTS with proper platform configuration.
  Future<void> _initTts() async {
    if (_isInitialized) {
      debugPrint('⚠️ TTS already initialized, skipping...');
      return;
    }

    debugPrint('🔊 Initializing TTS engine...');

    try {
      // Register handlers BEFORE configuring settings
      _tts.setStartHandler(() => debugPrint('🎤 TTS: Speech started'));
      _tts.setCompletionHandler(() => debugPrint('✅ TTS: Speech completed'));
      _tts.setErrorHandler((msg) => debugPrint('❌ TTS Error: $msg'));
      _tts.setCancelHandler(() => debugPrint('⏹️ TTS: Speech cancelled'));

      // Core TTS settings
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.5); // Natural speaking speed
      // ✅ FIX: volume must be in range 0.0–1.0.
      //    The original value of 3.0 is out-of-range and silently clamped/ignored.
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);

      if (Platform.isAndroid) {
        debugPrint('🤖 Applying Android-specific TTS settings...');

        // ✅ FIX: Do NOT call awaitSpeakCompletion(true) on Android.
        //    When set to true, it blocks the calling thread until speech finishes.
        //    This causes the audio session to be held open, and the subsequent
        //    _tts.stop() call (which was in triggerFeedback) releases focus —
        //    then _tts.speak() cannot re-acquire it in time, silently failing.
        //    Leaving it at the default (false) lets speak() be non-blocking
        //    and the audio system manages session handoff correctly.

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
        debugPrint('✅ iOS TTS settings applied');
      }

      // Verify TTS is working
      final languages = await _tts.getLanguages;
      if (languages != null && languages.isNotEmpty) {
        debugPrint('✅ TTS initialized successfully');
        debugPrint('   Available languages: ${languages.length}');
        debugPrint('   Using language: en-US');
      } else {
        debugPrint('⚠️ TTS initialized but no languages available');
      }

      _isInitialized = true;
    } catch (e) {
      debugPrint('❌ Failed to initialize TTS: $e');
      _isInitialized = true; // Prevent infinite retry loops
    }
  }

  /// Triggers haptic vibration immediately, then speaks the coaching message.
  ///
  /// Both haptic and voice share the same cooldown timer so they always fire
  /// together and are never split by independent gating.
  Future<void> triggerFeedback({
    required String message,
    required List<int> vibrationPattern,
  }) async {
    debugPrint('');
    debugPrint('═══════════════════════════════════════');
    debugPrint('🔔 Feedback Triggered');
    debugPrint('   Message: "$message"');
    debugPrint('   Vibration pattern: $vibrationPattern');

    // Lazy-initialize TTS on first use
    if (!_isInitialized) {
      debugPrint('   TTS not initialized, initializing now...');
      await _initTts();
    }

    final now = DateTime.now();

    // Cooldown check — prevents rapid-fire feedback spam
    if (_lastFeedbackTime != null) {
      final elapsed = now.difference(_lastFeedbackTime!);
      if (elapsed <= _cooldown) {
        final remaining = _cooldown - elapsed;
        debugPrint('⏳ Feedback blocked by cooldown');
        debugPrint('   ${remaining.inSeconds}s remaining');
        debugPrint('═══════════════════════════════════════');
        return;
      }
    }

    _lastFeedbackTime = now;

    try {
      // 1. Haptics — fire immediately, non-blocking
      debugPrint('📳 Triggering haptics...');
      if (await Vibration.hasVibrator() ?? false) {
        Vibration.vibrate(pattern: vibrationPattern);
        debugPrint('✅ Haptics triggered successfully');
      } else {
        debugPrint('⚠️ Device has no vibrator');
      }

      // 2. Voice — speak directly WITHOUT calling _tts.stop() first.
      //
      // ✅ FIX: The original code called `await _tts.stop()` here before
      //    `_tts.speak()`. On Android this releases the audio focus, and when
      //    speak() immediately tries to re-acquire it, the system denies it
      //    (focus was just released). The result: vibration fires correctly
      //    but voice is silently swallowed.
      //
      //    Removing stop() lets the TTS engine interrupt itself natively
      //    if speech is already in progress, which is the correct behaviour.
      debugPrint('🔊 Triggering TTS...');
      final result = await _tts.speak(message);

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

  /// Test voice from settings screen.
  Future<void> testVoice() async {
    if (!_isInitialized) await _initTts();
    // For manual test we can safely stop then speak — no audio-focus race here
    // because the user tapped a button and there is no concurrent speak() call.
    await _tts.stop();
    await _tts.speak('Hello! This is a test of the voice coaching system.');
    debugPrint('🎤 Test voice triggered');
  }

  /// Manually stop TTS (used during stopMonitoring cleanup).
  Future<void> stop() async {
    await _tts.stop();
    debugPrint('🛑 TTS stopped manually');
  }

  /// Dispose — called when the service is permanently torn down.
  void dispose() {
    _tts.stop();
    debugPrint('🗑️ CoachingService disposed');
  }
}