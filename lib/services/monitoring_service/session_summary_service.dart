import 'package:cloud_firestore/cloud_firestore.dart';

class SessionSummaryService {
  // Session tracking variables
  DateTime? _sessionStart;
  DateTime? _sessionEnd;

  double _maxSpeed = 0.0;
  double _minSpeed = double.infinity;
  double _speedSum = 0.0;
  int _speedCount = 0;

  int _harshAccelEvents = 0;
  int _harshBrakeEvents = 0;

  int _leftTurns = 0;
  int _rightTurns = 0;

  // NEW: Acceleration/Deceleration switch tracking
  int _accelToDecelSwitches = 0;
  int _decelToAccelSwitches = 0;
  String? _lastState; // "accel", "decel", or "neutral"

  // NEW: Speed zone tracking (for better analysis)
  int _stoppedTimeSeconds = 0; // Speed < 5 km/h
  int _slowTimeSeconds = 0;    // 5-40 km/h
  int _moderateTimeSeconds = 0; // 40-80 km/h
  int _fastTimeSeconds = 0;     // > 80 km/h

  // Getters
  DateTime? get sessionStart => _sessionStart;
  double get maxSpeed => _maxSpeed;
  double get minSpeed => _minSpeed;
  int get harshAccelEvents => _harshAccelEvents;
  int get harshBrakeEvents => _harshBrakeEvents;
  int get leftTurns => _leftTurns;
  int get rightTurns => _rightTurns;
  int get accelDecelSwitches => _accelToDecelSwitches + _decelToAccelSwitches;

  /// Start a new session
  void startSession() {
    _sessionStart = DateTime.now();
    _sessionEnd = null;
    _maxSpeed = 0.0;
    _minSpeed = double.infinity;
    _speedSum = 0.0;
    _speedCount = 0;
    _harshAccelEvents = 0;
    _harshBrakeEvents = 0;
    _leftTurns = 0;
    _rightTurns = 0;
    _accelToDecelSwitches = 0;
    _decelToAccelSwitches = 0;
    _lastState = null;
    _stoppedTimeSeconds = 0;
    _slowTimeSeconds = 0;
    _moderateTimeSeconds = 0;
    _fastTimeSeconds = 0;

    print('📊 Session started at $_sessionStart');
  }

  /// Update speed metrics (called every 500ms by monitoring service)
  void updateSpeed(double currentSpeed) {
    if (currentSpeed > _maxSpeed) {
      _maxSpeed = currentSpeed;
    }
    if (currentSpeed < _minSpeed && currentSpeed > 0) {
      _minSpeed = currentSpeed;
    }
    _speedSum += currentSpeed;
    _speedCount++;

    // Track time in different speed zones (approximation based on update frequency)
    if (currentSpeed < 5) {
      _stoppedTimeSeconds++;
    } else if (currentSpeed < 40) {
      _slowTimeSeconds++;
    } else if (currentSpeed < 80) {
      _moderateTimeSeconds++;
    } else {
      _fastTimeSeconds++;
    }
  }

  /// Track acceleration/deceleration state changes
  void updateAccelDecelState(String newState) {
    if (_lastState == null) {
      _lastState = newState;
      return;
    }

    // Detect state switches
    if (_lastState == "accel" && newState == "decel") {
      _accelToDecelSwitches++;
      print("🔄 Switch: Acceleration → Deceleration (Total: $_accelToDecelSwitches)");
    } else if (_lastState == "decel" && newState == "accel") {
      _decelToAccelSwitches++;
      print("🔄 Switch: Deceleration → Acceleration (Total: $_decelToAccelSwitches)");
    }

    _lastState = newState;
  }

  /// Increment harsh acceleration count
  void incrementHarshAccel() {
    _harshAccelEvents++;
  }

  /// Increment harsh braking count
  void incrementHarshBrake() {
    _harshBrakeEvents++;
  }

  /// Increment turn counts
  void incrementLeftTurn() {
    _leftTurns++;
  }

  void incrementRightTurn() {
    _rightTurns++;
  }

  /// Calculate session type probabilities
  Map<String, double> _calculateSessionTypeProbabilities({
    required double avgSpeed,
    required int totalSwitches,
    required int durationMinutes,
  }) {
    if (durationMinutes == 0) {
      return {'highwayProbability': 0.0, 'cityProbability': 0.0};
    }

    // Normalize switches per minute
    double switchesPerMinute = totalSwitches / durationMinutes;

    // Highway indicators:
    // - High average speed (>60 km/h)
    // - Low switches per minute (<3)
    // - High time in fast/moderate zones

    // City indicators:
    // - Low average speed (<40 km/h)
    // - High switches per minute (>5)
    // - High time in slow/stopped zones

    double highwayScore = 0.0;
    double cityScore = 0.0;

    // Speed-based scoring (0-40 points)
    if (avgSpeed > 70) {
      highwayScore += 40;
    } else if (avgSpeed > 50) {
      highwayScore += 25;
      cityScore += 5;
    } else if (avgSpeed > 30) {
      highwayScore += 10;
      cityScore += 20;
    } else {
      cityScore += 40;
    }

    // Switches-based scoring (0-30 points)
    if (switchesPerMinute < 2) {
      highwayScore += 30;
    } else if (switchesPerMinute < 4) {
      highwayScore += 15;
      cityScore += 10;
    } else if (switchesPerMinute < 7) {
      cityScore += 20;
    } else {
      cityScore += 30;
    }

    // Speed zone distribution scoring (0-30 points)
    int totalTimeUnits = _stoppedTimeSeconds + _slowTimeSeconds + _moderateTimeSeconds + _fastTimeSeconds;
    if (totalTimeUnits > 0) {
      double fastPercent = (_fastTimeSeconds + _moderateTimeSeconds) / totalTimeUnits;
      double slowPercent = (_slowTimeSeconds + _stoppedTimeSeconds) / totalTimeUnits;

      if (fastPercent > 0.6) {
        highwayScore += 30;
      } else if (fastPercent > 0.4) {
        highwayScore += 15;
      }

      if (slowPercent > 0.6) {
        cityScore += 30;
      } else if (slowPercent > 0.4) {
        cityScore += 15;
      }
    }

    // Normalize to probabilities (0-1 range)
    double totalScore = highwayScore + cityScore;
    if (totalScore == 0) {
      return {'highwayProbability': 0.5, 'cityProbability': 0.5};
    }
 // high = 300 // city 250 // 550 // 300= 0.6 // 250=0.4
    double highwayProbability = (highwayScore / totalScore).clamp(0.0, 1.0);
    double cityProbability = (cityScore / totalScore).clamp(0.0, 1.0);

    print('🛣️ Session Type Analysis:');
    print('   Highway Score: ${highwayScore.toStringAsFixed(1)}, Probability: ${(highwayProbability * 100).toStringAsFixed(1)}%');
    print('   City Score: ${cityScore.toStringAsFixed(1)}, Probability: ${(cityProbability * 100).toStringAsFixed(1)}%');

    return {
      'highwayProbability': highwayProbability,
      'cityProbability': cityProbability,
    };
  }

  /// Generate session summary as Map (NUMERICAL VALUES ONLY)
  Map<String, dynamic> generateSummary(double totalDistanceKm) {
    _sessionEnd = DateTime.now();
    final durationMinutes = _sessionEnd!.difference(_sessionStart!).inMinutes;
    final durationSeconds = _sessionEnd!.difference(_sessionStart!).inSeconds;
    final avgSpeed = _speedCount > 0 ? _speedSum / _speedCount : 0.0;
    final totalSwitches = _accelToDecelSwitches + _decelToAccelSwitches;

    // Calculate session type probabilities
    final probabilities = _calculateSessionTypeProbabilities(
      avgSpeed: avgSpeed,
      totalSwitches: totalSwitches,
      durationMinutes: durationMinutes,
    );

    final summary = {
      // Timestamps (stored as Firestore Timestamp for easy querying)
      'startTime': Timestamp.fromDate(_sessionStart!),
      'endTime': Timestamp.fromDate(_sessionEnd!),

      // Duration metrics
      'durationMinutes': durationMinutes,
      'durationSeconds': durationSeconds,

      // Distance metrics
      'distanceKm': double.parse(totalDistanceKm.toStringAsFixed(3)),

      // Speed metrics
      'maxSpeedKmh': double.parse(_maxSpeed.toStringAsFixed(2)),
      'minSpeedKmh': _minSpeed == double.infinity ? 0.0 : double.parse(_minSpeed.toStringAsFixed(2)),
      'avgSpeedKmh': double.parse(avgSpeed.toStringAsFixed(2)),

      // Harsh event metrics
      'harshAccelerations': _harshAccelEvents,
      'harshBrakes': _harshBrakeEvents,
      'totalHarshEvents': _harshAccelEvents + _harshBrakeEvents,

      // Turn metrics
      'leftTurns': _leftTurns,
      'rightTurns': _rightTurns,
      'totalTurns': _leftTurns + _rightTurns,

      // NEW: Acceleration/Deceleration switch metrics
      'accelToDecelSwitches': _accelToDecelSwitches,
      'decelToAccelSwitches': _decelToAccelSwitches,
      'totalSwitches': totalSwitches,
      'switchesPerMinute': durationMinutes > 0 ? double.parse((totalSwitches / durationMinutes).toStringAsFixed(2)) : 0.0,

      // NEW: Speed zone distribution (in seconds)
      'stoppedTimeSeconds': _stoppedTimeSeconds,
      'slowTimeSeconds': _slowTimeSeconds,
      'moderateTimeSeconds': _moderateTimeSeconds,
      'fastTimeSeconds': _fastTimeSeconds,

      // NEW: Session type probabilities (0-1 range)
      'highwayProbability': double.parse(probabilities['highwayProbability']!.toStringAsFixed(3)),
      'cityProbability': double.parse(probabilities['cityProbability']!.toStringAsFixed(3)),

      // Derived metrics
      'harshEventsPerMinute': durationMinutes > 0 ? double.parse(((_harshAccelEvents + _harshBrakeEvents) / durationMinutes).toStringAsFixed(2)) : 0.0,
      'turnsPerMinute': durationMinutes > 0 ? double.parse(((_leftTurns + _rightTurns) / durationMinutes).toStringAsFixed(2)) : 0.0,
    };

    print('📊 Session Summary Generated:');
    print('   Duration: $durationMinutes min ($durationSeconds sec)');
    print('   Distance: ${totalDistanceKm.toStringAsFixed(2)} km');
    print('   Avg Speed: ${avgSpeed.toStringAsFixed(1)} km/h (Min: ${summary['minSpeedKmh']}, Max: ${summary['maxSpeedKmh']})');
    print('   Harsh Events: $_harshAccelEvents accel, $_harshBrakeEvents brakes');
    print('   Turns: $_leftTurns left, $_rightTurns right');
    print('   Switches: $totalSwitches total (${summary['switchesPerMinute']}/min)');
    print('   Session Type: ${(probabilities['highwayProbability']! * 100).toStringAsFixed(0)}% Highway, ${(probabilities['cityProbability']! * 100).toStringAsFixed(0)}% City');

    return summary;
  }

  /// Save session summary to Firestore
  Future<void> saveSummary({
    required String userId,
    required String vehicleId,
    required double totalDistanceKm,
  }) async {
    final firestore = FirebaseFirestore.instance;
    final summary = generateSummary(totalDistanceKm);

    try {
      await firestore
          .collection('users')
          .doc(userId)
          .collection('sessions')
          .add(summary);

      print('✅ Session summary saved to Firestore');
    } catch (e) {
      print('❌ Failed to save session summary: $e');
      rethrow;
    }
  }

  /// Reset all session data
  void reset() {
    _sessionStart = null;
    _sessionEnd = null;
    _maxSpeed = 0.0;
    _minSpeed = double.infinity;
    _speedSum = 0.0;
    _speedCount = 0;
    _harshAccelEvents = 0;
    _harshBrakeEvents = 0;
    _leftTurns = 0;
    _rightTurns = 0;
    _accelToDecelSwitches = 0;
    _decelToAccelSwitches = 0;
    _lastState = null;
    _stoppedTimeSeconds = 0;
    _slowTimeSeconds = 0;
    _moderateTimeSeconds = 0;
    _fastTimeSeconds = 0;
  }
}