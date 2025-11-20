import 'package:cloud_firestore/cloud_firestore.dart';

class SessionSummaryService {
  // Session tracking variables
  DateTime? _sessionStart;
  DateTime? _sessionEnd;

  double _maxSpeed = 0.0;
  double _speedSum = 0.0;
  int _speedCount = 0;

  int _harshAccelEvents = 0;
  int _harshBrakeEvents = 0;

  int _leftTurns = 0;
  int _rightTurns = 0;

  // Getters for read-only access
  DateTime? get sessionStart => _sessionStart;
  double get maxSpeed => _maxSpeed;
  int get harshAccelEvents => _harshAccelEvents;
  int get harshBrakeEvents => _harshBrakeEvents;
  int get leftTurns => _leftTurns;
  int get rightTurns => _rightTurns;

  /// Start a new session
  void startSession() {
    _sessionStart = DateTime.now();
    _sessionEnd = null;
    _maxSpeed = 0.0;
    _speedSum = 0.0;
    _speedCount = 0;
    _harshAccelEvents = 0;
    _harshBrakeEvents = 0;
    _leftTurns = 0;
    _rightTurns = 0;
    print('📊 Session started at $_sessionStart');
  }

  /// Update speed metrics
  void updateSpeed(double currentSpeed) {
    if (currentSpeed > _maxSpeed) {
      _maxSpeed = currentSpeed;
    }
    _speedSum += currentSpeed;
    _speedCount++;
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

  /// Generate session summary as Map
  Map<String, dynamic> generateSummary(double totalDistanceKm) {
    _sessionEnd = DateTime.now();
    final avgSpeed = _speedCount > 0 ? _speedSum / _speedCount : 0;

    final summary = {
      'startTime': _sessionStart,
      'endTime': _sessionEnd,
      'duration': _sessionEnd!.difference(_sessionStart!).inMinutes,
      'distanceKm': totalDistanceKm,
      'maxSpeedKmh': _maxSpeed,
      'avgSpeedKmh': avgSpeed,
      'harshAccelerations': _harshAccelEvents,
      'harshBrakes': _harshBrakeEvents,
      'leftTurns': _leftTurns,
      'rightTurns': _rightTurns,
      'totalTurns': _leftTurns + _rightTurns,
    };

    print('📊 Session Summary Generated:');
    print('   Duration: ${summary['duration']} min');
    print('   Distance: ${totalDistanceKm.toStringAsFixed(2)} km');
    print('   Harsh Accel: $_harshAccelEvents, Harsh Brakes: $_harshBrakeEvents');
    print('   Left Turns: $_leftTurns, Right Turns: $_rightTurns');

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
          .collection('vehicles')
          .doc(vehicleId)
          .collection('trips')
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
    _speedSum = 0.0;
    _speedCount = 0;
    _harshAccelEvents = 0;
    _harshBrakeEvents = 0;
    _leftTurns = 0;
    _rightTurns = 0;
  }
}