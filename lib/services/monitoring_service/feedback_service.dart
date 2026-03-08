import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:raxxy/services/driver_profile_service.dart';
import 'package:raxxy/services/notifications_services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../Models/weather_model.dart';
import '../../providers/provider.dart';
import '../../providers/weather_api_provider.dart';

enum FeedbackCategory { turn, throttling, braking, speeding, smoothness, weather }

class DriverFeedback {
  final FeedbackCategory category;
  final double severity; // 0.0 – 1.0
  final String message;
  final String recommendation;
  final DateTime timestamp;

  DriverFeedback({
    required this.category,
    required this.severity,
    required this.message,
    required this.recommendation,
    required this.timestamp,
  });
}

class DriverProfile {
  final double avgHarshTurns;
  final double avgHarshAccels;
  final double avgHarshBrakes;
  final int totalSessions;
  final double avgSafetyScore;
  final Map<FeedbackCategory, int> categoryOccurrences;

  DriverProfile({
    required this.avgHarshTurns,
    required this.avgHarshAccels,
    required this.avgHarshBrakes,
    required this.totalSessions,
    required this.avgSafetyScore,
    required this.categoryOccurrences,
  });
}

class FeedbackService {
  static final FeedbackService _instance = FeedbackService._internal();
  factory FeedbackService() => _instance;
  FeedbackService._internal();

  final CoachingService _coachingService = CoachingService();
  final StreamController<DriverFeedback> _feedbackController =
  StreamController<DriverFeedback>.broadcast();

  Stream<DriverFeedback> get feedbackStream => _feedbackController.stream;

  bool _isInitialized = false;
  String? _currentUserId;

  // Default thresholds (overwritten after history is loaded)
  double _avgTurnForce = 2.0;
  double _avgAccel = 2.0;
  double _avgBrake = 2.0;

  // Historical profile data
  DriverProfile? _driverProfile;

  // Per-category cooldowns
  DateTime? _lastTurnFeedback;
  DateTime? _lastAccelFeedback;
  DateTime? _lastBrakeFeedback;
  DateTime? _lastWeatherFeedback;
  static const Duration _kFeedbackCooldown = Duration(seconds: 4);

  // ============================================================
  // INITIALISATION
  // ============================================================

  Future<void> initialize(String userId) async {
    if (_isInitialized && _currentUserId == userId) return;

    _currentUserId = userId;

    try {
      final history = await DriverProfileService.getLastSessions(userId: userId);
      if (history.isNotEmpty) {
        _calculateBenchmarks(history);
        _buildDriverProfile(history);
      }
      _isInitialized = true;
      debugPrint('✅ FeedbackService initialized with historical benchmarks');
    } catch (e) {
      debugPrint('❌ Error initializing FeedbackService: $e');
    }
  }

  // ============================================================
  // BENCHMARK & PROFILE BUILDING
  // ============================================================

  void _calculateBenchmarks(List<Map<String, dynamic>> sessions) {
    double totalAccel = 0;
    double totalBrake = 0;
    int count = 0;

    for (var session in sessions) {
      if (session['metrics'] != null) {
        final double harshRate =
        (session['metrics']['avgHarshEventsPerMin'] ?? 0.0).toDouble();

        if (harshRate > 0.5) {
          totalAccel += 2.5;
          totalBrake += 2.5;
        } else {
          totalAccel += 1.8;
          totalBrake += 1.8;
        }
        count++;
      }
    }

    if (count > 0) {
      _avgAccel = totalAccel / count;
      _avgBrake = totalBrake / count;
      _avgTurnForce = 2.0;
    }

    debugPrint(
      '📊 Customized Thresholds -> '
          'Accel: ${_avgAccel.toStringAsFixed(2)}, '
          'Brake: ${_avgBrake.toStringAsFixed(2)}',
    );
  }

  void _buildDriverProfile(List<Map<String, dynamic>> sessions) {
    double totalHarshTurns = 0;
    double totalHarshAccels = 0;
    double totalHarshBrakes = 0;
    double totalSafetyScore = 0;
    int validSessions = 0;

    final Map<FeedbackCategory, int> occurrences = {
      FeedbackCategory.turn: 0,
      FeedbackCategory.throttling: 0,
      FeedbackCategory.braking: 0,
      FeedbackCategory.speeding: 0,
      FeedbackCategory.smoothness: 0,
      FeedbackCategory.weather: 0,
    };

    for (var session in sessions) {
      if (session['metrics'] != null) {
        final metrics = session['metrics'];
        totalHarshTurns  += (metrics['harshTurns']         ?? 0).toDouble();
        totalHarshAccels += (metrics['harshAccelerations']  ?? 0).toDouble();
        totalHarshBrakes += (metrics['harshBrakes']         ?? 0).toDouble();
        totalSafetyScore += (metrics['safetyScore']         ?? 0).toDouble();
        validSessions++;
      }
    }

    if (validSessions > 0) {
      _driverProfile = DriverProfile(
        avgHarshTurns:      totalHarshTurns  / validSessions,
        avgHarshAccels:     totalHarshAccels / validSessions,
        avgHarshBrakes:     totalHarshBrakes / validSessions,
        totalSessions:      validSessions,
        avgSafetyScore:     totalSafetyScore / validSessions,
        categoryOccurrences: occurrences,
      );
      debugPrint(
        '📈 Driver Profile Built: '
            'Avg Safety Score: ${_driverProfile!.avgSafetyScore.toStringAsFixed(1)}',
      );
    }
  }

  // ============================================================
  // PERSONALISED RECOMMENDATIONS
  // ============================================================

  String _getPersonalizedRecommendation(
      FeedbackCategory category, double currentSeverity) {
    if (_driverProfile == null) return _getDefaultRecommendation(category);

    switch (category) {
      case FeedbackCategory.turn:
        return _getTurnRecommendation(currentSeverity);
      case FeedbackCategory.throttling:
        return _getThrottleRecommendation(currentSeverity);
      case FeedbackCategory.braking:
        return _getBrakeRecommendation(currentSeverity);
      case FeedbackCategory.weather:
        return _getWeatherRecommendation();
      default:
        return _getDefaultRecommendation(category);
    }
  }

  String _getTurnRecommendation(double severity) {
    final profile = _driverProfile!;

    if (profile.avgHarshTurns > 3.0) {
      return severity > 0.7
          ? 'That was a very sharp turn. Try slowing down to 15-20 km/h before entering curves. Your steering will feel more controlled.'
          : 'Remember to slow down before the turn, not during it. This gives you better control and smoother handling.';
    } else if (profile.avgHarshTurns > 1.0) {
      return severity > 0.7
          ? "A bit sharp there. You're improving, but aim to reduce speed earlier and maintain steady throttle through the turn."
          : 'Good progress! Try to anticipate turns even earlier to maintain your smoothness streak.';
    } else {
      return severity > 0.7
          ? 'Unusual for you! That turn was sharper than your typical smooth style. Everything okay?'
          : 'Just a gentle reminder: maintain that excellent cornering technique you usually demonstrate.';
    }
  }

  String _getThrottleRecommendation(double severity) {
    final profile = _driverProfile!;

    if (profile.avgHarshAccels > 3.0) {
      return severity > 0.7
          ? 'Heavy foot detected! Accelerate gradually to 60% throttle, then increase smoothly. This also saves fuel by up to 20%.'
          : 'Imagine an egg under your foot. Smooth acceleration is safer and more fuel-efficient.';
    } else if (profile.avgHarshAccels > 1.0) {
      return severity > 0.7
          ? "That was a bit aggressive. You've been doing well lately, try to maintain that smooth acceleration pattern."
          : "You're getting better at smooth starts. Keep building that muscle memory!";
    } else {
      return severity > 0.7
          ? "That's not like you! You're usually very smooth with acceleration. Let's get back to your excellent baseline."
          : "Almost perfect! You're among the smoothest drivers. Just a tiny adjustment to maintain your premium status.";
    }
  }

  String _getBrakeRecommendation(double severity) {
    final profile = _driverProfile!;

    if (profile.avgHarshBrakes > 3.0) {
      return severity > 0.7
          ? 'Hard braking alert! Scan 12-15 seconds ahead to anticipate stops. This reduces wear on your brakes by 30%.'
          : 'Practice the 3-second rule: maintain distance equal to 3 seconds of travel time. This gives you more time to brake gently.';
    } else if (profile.avgHarshBrakes > 1.0) {
      return severity > 0.7
          ? "A bit sudden there. You've improved your braking lately, let's maintain that progress by looking further ahead."
          : 'Your braking has improved significantly! Keep up the anticipation and smooth stops.';
    } else {
      return severity > 0.7
          ? "Whoa! That's unusual for someone with your smooth braking record. Stay focused and maintain your excellent habits."
          : 'Your braking technique is exemplary. This minor adjustment keeps you at the top of your game.';
    }
  }

  String _getWeatherRecommendation() {
    final profile = _driverProfile!;

    if (profile.avgSafetyScore > 80) {
      return 'Weather conditions detected. Given your excellent driving record, just apply your usual caution with extra time for reaction.';
    } else if (profile.avgSafetyScore > 60) {
      return 'Weather conditions require extra attention. Increase following distance and reduce speed by 10-15 km/h.';
    } else {
      return 'Adverse weather detected. Please drive extra carefully: reduce speed by 20%, double your following distance, and avoid sudden movements.';
    }
  }

  String _getDefaultRecommendation(FeedbackCategory category) {
    switch (category) {
      case FeedbackCategory.turn:
        return 'Slow down before entering the turn.';
      case FeedbackCategory.throttling:
        return 'Imagine an egg under your foot.';
      case FeedbackCategory.braking:
        return 'Scan ahead to anticipate stops.';
      case FeedbackCategory.weather:
        return 'Adjust driving to current weather conditions.';
      default:
        return 'Drive carefully and stay focused.';
    }
  }

  // ============================================================
  // PUBLIC EVALUATE METHODS
  // ============================================================

  // ✅ FIX: All evaluate methods now properly await _emitFeedback() so the
  //    async TTS chain (triggerFeedback inside _emitFeedback) is not orphaned.

  Future<void> evaluateTurn(double lateralForce, double speedKmh) async {
    if (lateralForce.abs() < _avgTurnForce * 1.2) return;
    if (!_canTrigger(_lastTurnFeedback)) return;

    _lastTurnFeedback = DateTime.now();

    final severity = (lateralForce.abs() / 5.0).clamp(0.0, 1.0);
    final String msg =
    speedKmh > 50 ? 'Taking that turn a bit fast!' : 'Sharp turn detected.';
    final String recommendation =
    _getPersonalizedRecommendation(FeedbackCategory.turn, severity);

    await _emitFeedback(
      category: FeedbackCategory.turn,
      severity: severity,
      message: msg,
      recommendation: recommendation,
      vibrationPattern: [0, 200, 100, 200],
    );
  }

  Future<void> evaluateAcceleration(double magnitude, double speedKmh) async {
    if (magnitude < _avgAccel * 1.2) return;
    if (!_canTrigger(_lastAccelFeedback)) return;

    _lastAccelFeedback = DateTime.now();

    final severity = (magnitude / 5.0).clamp(0.0, 1.0);
    final String recommendation =
    _getPersonalizedRecommendation(FeedbackCategory.throttling, severity);

    await _emitFeedback(
      category: FeedbackCategory.throttling,
      severity: severity,
      message: 'Easy on the gas!',
      recommendation: recommendation,
      vibrationPattern: [0, 200],
    );
  }

  Future<void> evaluateBraking(double magnitude, double speedKmh) async {
    if (magnitude < _avgBrake * 1.2) return;
    if (!_canTrigger(_lastBrakeFeedback)) return;

    _lastBrakeFeedback = DateTime.now();

    final severity = (magnitude / 5.0).clamp(0.0, 1.0);
    final String recommendation =
    _getPersonalizedRecommendation(FeedbackCategory.braking, severity);

    await _emitFeedback(
      category: FeedbackCategory.braking,
      severity: severity,
      message: 'Hard braking detected.',
      recommendation: recommendation,
      vibrationPattern: [0, 500],
    );
  }

  bool _canTrigger(DateTime? lastTime) {
    if (lastTime == null) return true;
    return DateTime.now().difference(lastTime) > _kFeedbackCooldown;
  }

  Future<void> evaluateWeather(WidgetRef ref) async {
    if (!_canTrigger(_lastWeatherFeedback)) return;

    try {
      final Position position = await _determinePosition();
      final data = await ref.read(
        weatherProvider(
            (lat: position.latitude, lon: position.longitude))
            .future,
      );
      final int conditionId = data.current.id;

      String message = '';
      double severity = 0.5;

      if (conditionId >= 200 && conditionId < 300) {
        message = 'Thunderstorm detected.';
        severity = 0.9;
      } else if (conditionId >= 500 && conditionId < 600) {
        message = 'Rainy conditions detected.';
        severity = 0.6;
      } else if (conditionId >= 600 && conditionId < 700) {
        message = 'Snow detected on the road.';
        severity = 0.8;
      } else if (conditionId >= 700 && conditionId < 800) {
        message = 'Low visibility due to fog or mist.';
        severity = 0.7;
      } else if (conditionId == 800) {
        return; // Clear — no alert needed
      } else if (conditionId > 800) {
        message = 'Cloudy skies detected.';
        severity = 0.3;
      }

      _lastWeatherFeedback = DateTime.now();

      final String recommendation =
      _getPersonalizedRecommendation(FeedbackCategory.weather, severity);

      await _emitFeedback(
        category: FeedbackCategory.weather,
        severity: severity,
        message: message,
        recommendation: recommendation,
        vibrationPattern: [0, 300, 100, 300],
      );
    } catch (e) {
      debugPrint('❌ Error evaluating weather: $e');
    }
  }

  Future<void> evaluateAccidentRisk(
      String currentRiskLevel, double currentRiskScore) async {
    if (currentRiskLevel == 'High') {
      await _emitFeedback(
        category: FeedbackCategory.weather,
        severity: 0.7,
        message: 'High accident risk detected.',
        recommendation: 'Try to lower your speed to reduce risk.',
        vibrationPattern: [0, 300, 100, 300],
      );
    }
  }

  // ============================================================
  // INTERNAL HELPERS
  // ============================================================

  Future<Position> _determinePosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions denied.');
      }
    }

    return Geolocator.getCurrentPosition();
  }

  // ✅ FIX: Changed from `void` to `Future<void>` and made async so that
  //    `await _coachingService.triggerFeedback(...)` is properly awaited.
  //    Previously this was a sync void method, meaning triggerFeedback() was
  //    called as a fire-and-forget Future — if anything failed in the async
  //    TTS chain there was no error surface and voice silently dropped.
  Future<void> _emitFeedback({
    required FeedbackCategory category,
    required double severity,
    required String message,
    required String recommendation,
    required List<int> vibrationPattern,
  }) async {
    final feedback = DriverFeedback(
      category: category,
      severity: severity,
      message: message,
      recommendation: recommendation,
      timestamp: DateTime.now(),
    );

    _feedbackController.add(feedback);

    // ✅ Properly awaited — TTS Future is no longer orphaned
    await _coachingService.triggerFeedback(
      message: '$message $recommendation',
      vibrationPattern: vibrationPattern,
    );
  }

  void dispose() {
    _feedbackController.close();
  }
}