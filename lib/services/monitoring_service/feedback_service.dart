import 'dart:async';
import 'package:raxxy/services/driver_profile_service.dart';
import 'package:raxxy/services/notifications_services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../Models/weather_model.dart';
import '../../providers/weather_api_provider.dart';

enum FeedbackCategory { turn, throttling, braking, speeding, smoothness, weather}

class DriverFeedback {
  final FeedbackCategory category;
  final double severity; // 0.0 - 1.0
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

class FeedbackService {

  static final FeedbackService _instance = FeedbackService._internal();

  factory FeedbackService() => _instance;

  FeedbackService._internal();

  final CoachingService _coachingService = CoachingService();
  final StreamController<DriverFeedback> _feedbackController = StreamController<DriverFeedback>.broadcast();

  Stream<DriverFeedback> get feedbackStream => _feedbackController.stream;

  bool _isInitialized = false;

  // Default thresholds
  double _avgTurnForce = 2.0;
  double _avgAccel = 2.0;
  double _avgBrake = 2.0; // Fixed typo in variable name context

  // Cooldowns
  DateTime? _lastTurnFeedback;
  DateTime? _lastAccelFeedback;
  DateTime? _lastBrakeFeedback;
  static const Duration _kFeedbackCooldown = Duration(seconds: 4);

  Future<void> initialize(String userId) async {
    if (_isInitialized) return;

    try {
      final history = await DriverProfileService.getLastSessions(userId: userId);
      if (history.isNotEmpty) {
        _calculateBenchmarks(history);
      }
      _isInitialized = true;
      print('✅ FeedbackService initialized with historical benchmarks');
    } catch (e) {
      print('❌ Error initializing FeedbackService: $e');
    }
  }

  void _calculateBenchmarks(List<Map<String, dynamic>> sessions) {
    double totalTurnForce = 0; // Placeholder for future detailed metrics
    double totalAccel = 0;
    double totalBrake = 0;
    int count = 0;

    for (var session in sessions) {
      // Logic to adjust thresholds based on driver history
      // If the driver is generally good (low harsh events), we lower the threshold 
      // to help them maintain that "Premium" feel (gentle coaching).
      // If the driver is aggressive, we raise it slightly so we don't spam them constantly.
      if (session['metrics'] != null) {
        final double harshRate = (session['metrics']['avgHarshEventsPerMin'] ?? 0.0).toDouble();

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
      _avgTurnForce = 2.0; // Default for now until lateral force metrics are stored
    }
    
    print('📊 Customized Thresholds -> Accel: ${_avgAccel.toStringAsFixed(2)}, Brake: ${_avgBrake.toStringAsFixed(2)}');
  }

  void evaluateTurn(double lateralForce, double speedKmh) {
    if (lateralForce.abs() < _avgTurnForce * 1.2) return;
    if (!_canTrigger(_lastTurnFeedback)) return;

    _lastTurnFeedback = DateTime.now();

    String msg = speedKmh > 50 ? "Taking that turn a bit fast!" : "Sharp turn detected.";
    
    _emitFeedback(
      category: FeedbackCategory.turn,
      severity: (lateralForce.abs() / 5.0).clamp(0.0, 1.0),
      message: msg,
      recommendation: "Slow down before entering the turn.",
      vibrationPattern: [0, 200, 100, 200],
    );
  }

  void evaluateAcceleration(double magnitude, double speedKmh) {
     if (magnitude < _avgAccel * 1.2) return;
     if (!_canTrigger(_lastAccelFeedback)) return;

     _lastAccelFeedback = DateTime.now();
     
     _emitFeedback(
       category: FeedbackCategory.throttling,
       severity: (magnitude / 5.0).clamp(0.0, 1.0),
       message: "Easy on the gas!",
       recommendation: "Imagine an egg under your foot.",
       vibrationPattern: [0, 200],
     );
  }

  void evaluateBraking(double magnitude, double speedKmh) {
    if (magnitude < _avgBrake * 1.2) return;
    if (!_canTrigger(_lastBrakeFeedback)) return;

    _lastBrakeFeedback = DateTime.now();

    _emitFeedback(
      category: FeedbackCategory.braking,
      severity: (magnitude / 5.0).clamp(0.0, 1.0),
      message: "Hard braking detected.",
      recommendation: "Scan ahead to anticipate stops.",
       vibrationPattern: [0, 500],
    );
  }

  bool _canTrigger(DateTime? lastTime) {
    if (lastTime == null) return true;
    return DateTime.now().difference(lastTime) > _kFeedbackCooldown;
  }

  void evaluateWeather(WeatherBase data) async {
    final int conditionId = data.id; // Assuming you added 'id' to your WeatherBase model
    final String description = data.description;


    String message = "";
    String recommendation = "";
    double severity = 0.5; // Default severity

    // 2. Logic based on OpenWeather Condition IDs
    // 2xx: Thunderstorm, 3xx: Drizzle, 5xx: Rain, 6xx: Snow, 7xx: Atmosphere (Fog)
    if (conditionId >= 200 && conditionId < 300) {
      message = "Thunderstorm detected.";
      recommendation = "Seek cover if visibility is poor.";
      severity = 0.9;
    }
    else if (conditionId >= 500 && conditionId < 600) {
      message = "Rainy conditions detected.";
      recommendation = "It's a rainy day, take your departure before time to account for traffic.";
      severity = 0.6;
    }
    else if (conditionId == 800) {
      // Usually, we don't alert for clear weather, but you can for high UV/Heat
      return;
    }
    else if (conditionId > 800) {
      message = "Cloudy skies.";
      recommendation = "Visibility may vary, stay alert.";
      severity = 0.3;
    }

    // 3. Emit the feedback if a message was set
    _emitFeedback(
      category: FeedbackCategory.weather, // Add 'weather' to your FeedbackCategory enum
      severity: severity,
      message: message,
      recommendation: recommendation,
      vibrationPattern: [0, 300, 100, 300], // Distinct pattern for weather
    );
  }

  void _emitFeedback({
    required FeedbackCategory category,
    required double severity,
    required String message,
    required String recommendation,
    required List<int> vibrationPattern,
  }) {
    final feedback = DriverFeedback(
      category: category,
      severity: severity,
      message: message,
      recommendation: recommendation,
      timestamp: DateTime.now(),
    );

    _feedbackController.add(feedback);
    
    // Trigger Voice & Haptics
    _coachingService.triggerFeedback(
      message: message,
      vibrationPattern: vibrationPattern,
    );
  }
  
  void dispose() {
    _feedbackController.close();
  }
}
