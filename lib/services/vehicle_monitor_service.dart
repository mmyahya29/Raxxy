import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:raxxy/services/crash_detector.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../providers/provider.dart';
import '../providers/safety_feature_provider.dart';
import 'notifications_services.dart';

class VehicleMonitorService {
  final ValueNotifier<String?> monitoredVehicleIdNotifier = ValueNotifier(null);
  final ValueNotifier<double> currentSpeedNotifier = ValueNotifier(0.0);
  final ValueNotifier<double> currentAccelerationNotifier = ValueNotifier(0.0);
  final ValueNotifier<double> currentDistanceNotifier = ValueNotifier(0.0);

  static final VehicleMonitorService _instance =
  VehicleMonitorService._internal();

  factory VehicleMonitorService() => _instance;

  VehicleMonitorService._internal();

  StreamSubscription<UserAccelerometerEvent>? _accelSub;
  StreamSubscription<Position>? _positionSub;
  Timer? _uiUpdateTimer;

  UserAccelerometerEvent? currentAcceleration;
  double currentSpeedKmh = 0.0;

  final List<Map<String, dynamic>> _speedHistory = [];

  double totalDistanceMeters = 0.0;
  Position? _lastPosition;

  bool _isMonitoring = false;

  // Updated threshold values for better reliability
  final double accelerationThreshold = 2.0;
  final double decelerationThreshold = -2.0;

  final List<double> _accelBuffer = [];
  final int _acBufferSize = 10;

  // NEW filtering parameters to reduce false positives
  final double minSpeedThreshold =
  0.0; // km/h - only detect harsh events above this speed
  final int sustainedSampleCount =
  1; // Need 5 consecutive samples above threshold
  final double jitterThreshold = 2.0; // Max std deviation to filter noise

  String? _userId;
  String? _vehicleId;

  // Notification cooldown
  DateTime? _lastHarshAccelNotification;
  DateTime? _lastHarshBrakeNotification;
  final Duration _notificationCooldown = const Duration(seconds: 5);

  // Crash detection cooldown
  DateTime? _lastCrashDetection;
  final Duration _crashCooldown = const Duration(seconds: 10);

  // tracking variables for sustained events
  int _consecutiveHarshAccel = 0;
  int _consecutiveHarshBrake = 0;

  // Variables for session summary
  DateTime? _sessionStart;
  DateTime? _sessionEnd;

  double _maxSpeed = 0.0;
  double _speedSum = 0.0;
  int _speedCount = 0;

  int _harshAccelEvents = 0;
  int _harshBrakeEvents = 0;

  // Store BuildContext for scaffold messages
  BuildContext? _monitoringContext;

  // TURN DETECTION VARIABLES

  // Store last accelerometer reading for angle calculation
  double? _lastAccelX;
  double? _lastAccelY;

  // Turn detection threshold (in degrees)
  final double turnAngleThreshold = 15.0;

  // Turn detection cooldown to avoid spam
  DateTime? _lastTurnDetection;
  final Duration _turnCooldown = const Duration(seconds: 2);

  // Minimum speed to detect turns
  final double minSpeedForTurnDetection = 10.0;

  // Turn counter for session summary
  int _leftTurns = 0;
  int _rightTurns = 0;


  Future<void> startMonitoring({
    required BuildContext context,
    required String userId,
    required String vehicleId,
    required String make,
    required String model,
    required WidgetRef ref,
  }) async {
    if (_isMonitoring) return;
    _isMonitoring = true;
    _userId = userId;
    _vehicleId = vehicleId;
    _monitoringContext = context; // Store context for scaffold messages

    // Session summary values reset
    _sessionStart = DateTime.now();
    _sessionEnd = null;
    _maxSpeed = 0.0;
    _speedSum = 0.0;
    _speedCount = 0;
    _harshAccelEvents = 0;
    _harshBrakeEvents = 0;
    _lastCrashDetection = null;

    // Reset consecutive counters
    _consecutiveHarshAccel = 0;
    _consecutiveHarshBrake = 0;

    // Reset turn detection variables
    _lastAccelX = null;
    _lastAccelY = null;
    _lastTurnDetection = null;
    _leftTurns = 0;
    _rightTurns = 0;

    ref.read(vehicleMonitorProvider.notifier).setVehicle(vehicleId);
    ref.read(vehicleMonitorProvider.notifier).setMake(make);
    ref.read(vehicleMonitorProvider.notifier).setModel(model);
    final crashFeature = ref.watch(featureNotifierProvider);

    sendNotification("RAXXY", "Monitoring service started");

    try {
      await WakelockPlus.enable();
      print('Wakelock enabled - screen will stay on while monitoring');
    } catch (e) {
      print('Failed to enable wakelock: $e');
    }

    // Start UI update timer (updates every 500ms instead of every sensor event)
    _uiUpdateTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (_accelBuffer.isNotEmpty) {
        double avgAccel =
            _accelBuffer.reduce((a, b) => a + b) / _accelBuffer.length;
        ref.read(vehicleMonitorProvider.notifier).updateAcceleration(avgAccel);
      }
      ref.read(vehicleMonitorProvider.notifier).updateSpeed(currentSpeedKmh);
      ref
          .read(vehicleMonitorProvider.notifier)
          .updateDistance(totalDistanceMeters);
    });

    // IMPROVED ACCELEROMETER LOGIC - More reliable harsh event detection + TURN DETECTION
    _accelSub = userAccelerometerEvents.listen((event) {
      currentAcceleration = event;

      // TURN DETECTION
      _detectTurn(event.x, event.y);

      // Use Y-axis as primary direction indicator (forward/backward)
      // Positive = forward acceleration, Negative = braking/deceleration
      double directedAccel = event.y;

      _accelBuffer.add(directedAccel);
      if (_accelBuffer.length > _acBufferSize) {
        _accelBuffer.removeAt(0);
      }

      // Only check for harsh events if buffer is full AND vehicle is moving
      if (_accelBuffer.length == _acBufferSize &&
          currentSpeedKmh > minSpeedThreshold) {
        double avgAccel =
            _accelBuffer.reduce((a, b) => a + b) / _accelBuffer.length;

        // Calculate standard deviation to detect jitter/noise
        double variance = 0;
        for (double val in _accelBuffer) {
          variance += pow(val - avgAccel, 2);
        }
        double stdDev = sqrt(variance / _accelBuffer.length);

        // If too much jitter/noise, skip detection to avoid false positives
        if (stdDev > jitterThreshold) {
          _consecutiveHarshAccel = 0;
          _consecutiveHarshBrake = 0;
          return;
        }

        // Check for sustained harsh acceleration
        if (avgAccel > accelerationThreshold) {
          _consecutiveHarshAccel++;
          _consecutiveHarshBrake = 0; // Reset brake counter

          // Only trigger if sustained over multiple samples
          if (_consecutiveHarshAccel >= sustainedSampleCount) {
            if (_shouldSendNotification(_lastHarshAccelNotification)) {
              _harshAccelEvents++; // Only increment when actually notifying
              _lastHarshAccelNotification = DateTime.now();
              sendNotification(
                "Woah Buddy! Easy on the Gas",
                "Acceleration: ${avgAccel.toStringAsFixed(2)} m/s² at ${currentSpeedKmh.toStringAsFixed(0)} km/h",
              );
              _consecutiveHarshAccel = 0; // Reset after notification
            }
          }
        }
        // Check for sustained harsh braking
        else if (avgAccel < decelerationThreshold) {
          _consecutiveHarshBrake++;
          _consecutiveHarshAccel = 0; // Reset accel counter

          // Only trigger if sustained over multiple samples
          if (_consecutiveHarshBrake >= sustainedSampleCount) {
            if (_shouldSendNotification(_lastHarshBrakeNotification)) {
              _harshBrakeEvents++; // Only increment when actually notifying
              _lastHarshBrakeNotification = DateTime.now();
              sendNotification(
                "Woah Buddy! Easy on the Brakes",
                "Deceleration: ${avgAccel.toStringAsFixed(2)} m/s² at ${currentSpeedKmh.toStringAsFixed(0)} km/h",
              );
              _consecutiveHarshBrake = 0; // Reset after notification
            }
          }
        } else {
          // Reset counters if we're in normal driving range
          _consecutiveHarshAccel = 0;
          _consecutiveHarshBrake = 0;
        }

        // Check for crash - high acceleration fluctuation
        if (crashFeature == true) {
          _checkCrashFromAcceleration(context, ref, avgAccel);
        }
      } else if (currentSpeedKmh <= minSpeedThreshold) {
        // Reset counters when stationary or moving very slowly
        _consecutiveHarshAccel = 0;
        _consecutiveHarshBrake = 0;
      }
    });

    // Check location permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        print('Location permission not granted');
        return;
      }
    }

    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 1,
      ),
    ).listen((position) {
      final now = DateTime.now();
      currentSpeedKmh = position.speed * 3.6;

      // Track max speed
      _maxSpeed = max(_maxSpeed, currentSpeedKmh);

      // Track average speed
      _speedSum += currentSpeedKmh;
      _speedCount++;

      // Store speed history for crash detection
      _speedHistory.add({'time': now, 'speed': currentSpeedKmh});
      if (_speedHistory.length > 10) _speedHistory.removeAt(0);

      // Check for sudden speed drop (crash detection)
      if (crashFeature == true && _speedHistory.length >= 2) {
        _checkCrashFromSpeedDrop(context, ref);
      }

      // Calculate distance
      if (_lastPosition != null) {
        double distance = Geolocator.distanceBetween(
          _lastPosition!.latitude,
          _lastPosition!.longitude,
          position.latitude,
          position.longitude,
        );

        totalDistanceMeters += distance;
      }

      _lastPosition = position;
    });

    print('Monitoring started with turn detection enabled');
  }

  // Turn detection
  void _detectTurn(double currentX, double currentY) {
    // Only detect turns if vehicle is moving above threshold speed
    if (currentSpeedKmh < minSpeedForTurnDetection) {
      _lastAccelX = currentX;
      _lastAccelY = currentY;
      return;
    }

    // Check cooldown
    if (_lastTurnDetection != null &&
        DateTime.now().difference(_lastTurnDetection!) < _turnCooldown) {
      return;
    }

    // Need previous reading to calculate angle
    if (_lastAccelX == null || _lastAccelY == null) {
      _lastAccelX = currentX;
      _lastAccelY = currentY;
      return;
    }

    // Calculate angle between last and current position vectors
    // Using atan2 to get angle in radians, then convert to degrees
    double lastAngle = atan2(_lastAccelY!, _lastAccelX!);
    double currentAngle = atan2(currentY, currentX);

    // Calculate the difference in angles
    double angleDifference = currentAngle - lastAngle;

    // Normalize angle difference to range [-π, π]
    while (angleDifference > pi) angleDifference -= 2 * pi;
    while (angleDifference < -pi) angleDifference += 2 * pi;

    // Convert to degrees
    double angleDifferenceInDegrees = angleDifference * (180 / pi);

    // Check if angle exceeds threshold
    if (angleDifferenceInDegrees.abs() > turnAngleThreshold) {
      // Determine turn direction
      String turnDirection;
      if (angleDifferenceInDegrees > 0) {
        turnDirection = "Left";
        _leftTurns++;
      } else {
        turnDirection = "Right";
        _rightTurns++;
      }

      // Log the turn detection
      print(
          "🔄 Turn Detected: $turnDirection turn "
              "(${angleDifferenceInDegrees.abs().toStringAsFixed(1)}° at ${currentSpeedKmh.toStringAsFixed(0)} km/h)"
      );

      // Update cooldown
      _lastTurnDetection = DateTime.now();
    }

    // Update last readings
    _lastAccelX = currentX;
    _lastAccelY = currentY;
  }


  bool _shouldSendNotification(DateTime? lastNotification) {
    if (lastNotification == null) return true;
    return DateTime.now().difference(lastNotification) > _notificationCooldown;
  }

  void _checkCrashFromAcceleration(
      BuildContext context,
      WidgetRef ref,
      double avgAccel,
      ) {
    // Check if enough time has passed since last crash detection
    if (_lastCrashDetection != null &&
        DateTime.now().difference(_lastCrashDetection!) < _crashCooldown) {
      return;
    }

    // Calculate acceleration fluctuation
    if (_accelBuffer.length < 2) return;

    double accelFluctuation =
        _accelBuffer[_accelBuffer.length - 1] -
            _accelBuffer[_accelBuffer.length - 2];

    // If high jitter/fluctuation detected
    if (accelFluctuation.abs() > 1) {
      _triggerCrashDetection(context, ref);
    }
  }

  void _checkCrashFromSpeedDrop(BuildContext context, WidgetRef ref) {
    // Check if enough time has passed since last crash detection
    if (_lastCrashDetection != null &&
        DateTime.now().difference(_lastCrashDetection!) < _crashCooldown) {
      return;
    }

    if (_speedHistory.length < 2) return;

    final recent = _speedHistory[_speedHistory.length - 1];
    final previous = _speedHistory[_speedHistory.length - 2];

    final delTime =
        recent['time'].difference(previous['time']).inMilliseconds / 1000.0;
    final delSpeed = recent['speed'] - previous['speed'];

    // Sudden speed drop > 15 km/h in < 1.5 seconds
    if (delSpeed < -15 && delTime < 1.5) {
      _triggerCrashDetection(context, ref);
    }
  }

  void _triggerCrashDetection(BuildContext context, WidgetRef ref) {
    _lastCrashDetection = DateTime.now();
    print("CRASH DETECTED - Triggering crash protocol");

    sendNotification("Crash Detected", "Possible impact detected");

    // Run crash detection on next frame to avoid blocking
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        CrashDetector.checkForCrash(
          context,
          ref,
          onDialogClosed: () {
            // No need to reset flag anymore as we're using cooldown
            print("Crash dialog closed");
          },
        );
      }
    });
  }

  Future<void> stopMonitoring(WidgetRef ref, {double? manualMileage}) async {
    _accelSub?.cancel();
    _positionSub?.cancel();
    _uiUpdateTimer?.cancel();

    _lastPosition = null;
    _isMonitoring = false;

    try {
      await WakelockPlus.disable();
      print('Wakelock disabled - screen may sleep now');
    } catch (e) {
      print('Failed to disable wakelock: $e');
    }

    final summary = generateSessionSummary();

    // Print turn statistics
    print("📊 Session Turn Statistics:");
    print("   Left Turns: $_leftTurns");
    print("   Right Turns: $_rightTurns");
    print("   Total Turns: ${_leftTurns + _rightTurns}");

    // Update mileage ONCE when stopping (instead of every GPS update)
    if (_userId != null && _vehicleId != null) {
      try {
        final firestore = FirebaseFirestore.instance;
        final vehicleDoc = firestore
            .collection('users')
            .doc(_userId)
            .collection('vehicles')
            .doc(_vehicleId);

        // Use manual mileage if provided, otherwise use GPS-calculated distance
        final mileageToAdd = manualMileage ?? (totalDistanceMeters / 1000);

        // Update vehicle mileage
        await firestore.runTransaction((transaction) async {
          final snapshot = await transaction.get(vehicleDoc);
          if (snapshot.exists) {
            final currentMileage = snapshot.data()?['mileage'] ?? 0;
            transaction.update(vehicleDoc, {
              'mileage': currentMileage + mileageToAdd.round(),
            });
          }
        });

        // Show success message for mileage update
        if (_monitoringContext != null && _monitoringContext!.mounted) {
          ScaffoldMessenger.of(_monitoringContext!).showSnackBar(
            SnackBar(
              content: Text(
                '✅ Mileage updated: +${mileageToAdd.toStringAsFixed(2)} km',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }

        // Small delay between messages
        await Future.delayed(const Duration(milliseconds: 500));

        // Save trip summary
        await vehicleDoc.collection('trips').add(summary);

        // Show success message for trip saved
        if (_monitoringContext != null && _monitoringContext!.mounted) {
          ScaffoldMessenger.of(_monitoringContext!).showSnackBar(
            SnackBar(
              content: Text(
                '💾 Trip summary saved (${summary['duration']} min, ${summary['distanceKm'].toStringAsFixed(1)} km)',
              ),
              backgroundColor: Colors.blue,
              duration: const Duration(seconds: 2),
            ),
          );
        }

        await Future.delayed(const Duration(milliseconds: 500));

        // Update driving score
        await _updateDrivingScore();

        // Show success message for driving score
        if (_monitoringContext != null && _monitoringContext!.mounted) {
          ScaffoldMessenger.of(_monitoringContext!).showSnackBar(
            SnackBar(
              content: Text(
                '📊 Driving score updated ($_harshAccelEvents harsh accel, $_harshBrakeEvents harsh brakes)',
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 2),
            ),
          );
        }

        await Future.delayed(const Duration(milliseconds: 500));

        // Generate goals based on session performance
        await _generateGoals();

        // Show success message for goals
        if (_monitoringContext != null && _monitoringContext!.mounted) {
          ScaffoldMessenger.of(_monitoringContext!).showSnackBar(
            const SnackBar(
              content: Text('🎯 Goals updated based on your performance'),
              backgroundColor: Colors.purple,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        print('Failed to update vehicle data: $e');
        // Show error message
        if (_monitoringContext != null && _monitoringContext!.mounted) {
          ScaffoldMessenger.of(_monitoringContext!).showSnackBar(
            SnackBar(
              content: Text('❌ Error: ${e.toString()}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }

    ref.read(vehicleMonitorProvider.notifier).clear();
    _monitoringContext = null; // Clear context
    print('Monitoring stopped');
  }

  Map<String, dynamic> generateSessionSummary() {
    _sessionEnd = DateTime.now();
    final avgSpeed = _speedCount > 0 ? _speedSum / _speedCount : 0;

    return {
      'startTime': _sessionStart,
      'endTime': _sessionEnd,
      'duration': _sessionEnd!.difference(_sessionStart!).inMinutes,
      'distanceKm': totalDistanceMeters / 1000,
      'maxSpeedKmh': _maxSpeed,
      'avgSpeedKmh': avgSpeed,
      'harshAccelerations': _harshAccelEvents,
      'harshBrakes': _harshBrakeEvents,
      'leftTurns': _leftTurns,  // Added turn data to summary
      'rightTurns': _rightTurns,  // Added turn data to summary
      'totalTurns': _leftTurns + _rightTurns,  // Added total turns
    };
  }

  Future<void> _updateDrivingScore() async {
    if (_userId == null) return;

    final firestore = FirebaseFirestore.instance;
    final userDoc = firestore.collection('users').doc(_userId);

    try {
      await firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(userDoc);
        if (!snapshot.exists) return;

        double currentScore = snapshot.data()?['drivingScore'] ?? 50.0;

        // Calculate penalty based on harsh events per minute
        final duration = _sessionEnd!.difference(_sessionStart!).inMinutes;
        if (duration == 0) return;

        final harshEventsPerMinute =
            (_harshAccelEvents + _harshBrakeEvents) / duration;

        // Adjust score based on performance
        double scoreAdjustment;
        if (harshEventsPerMinute <= 0.1) {
          scoreAdjustment = 1.0; // Good driving
        } else if (harshEventsPerMinute <= 0.3) {
          scoreAdjustment = 0.0; // Neutral
        } else {
          scoreAdjustment = -1.0; // Poor driving
        }

        // Update score (clamped between 0-100)
        double newScore = (currentScore + scoreAdjustment).clamp(0.0, 100.0);

        transaction.update(userDoc, {'drivingScore': newScore});
      });
    } catch (e) {
      print('Failed to update driving score: $e');
    }
  }

  Future<void> _generateGoals() async {
    if (_userId == null || _vehicleId == null) return;

    final firestore = FirebaseFirestore.instance;
    final goalsCollection = firestore
        .collection('users')
        .doc(_userId)
        .collection('goals');

    // Get current goals
    final currentGoalsSnapshot = await goalsCollection.get();
    final currentGoals =
    currentGoalsSnapshot.docs
        .map((doc) => {...doc.data(), 'id': doc.id})
        .toList();

    final summary = generateSessionSummary();
    final int accHarshEvents = (summary["harshAccelerations"] ?? 0);
    final int brHarshEvents = (summary["harshBrakes"] ?? 0);
    final int durationMinutes = summary["duration"] ?? 0;

    if (durationMinutes == 0) return;

    double accEventsPerMinute = accHarshEvents / durationMinutes;
    double brEventsPerMinute = brHarshEvents / durationMinutes;

    // Delete completed goals
    for (var goal in currentGoals) {
      bool shouldDelete = false;

      if (goal["title"] == "Improve Smooth Throttle" &&
          accEventsPerMinute < 0.2) {
        shouldDelete = true;
      } else if (goal["title"] == "Improve Smooth Braking" &&
          brEventsPerMinute < 0.2) {
        shouldDelete = true;
      }

      if (shouldDelete) {
        await firestore
            .collection('users')
            .doc(_userId)
            .collection('goals')
            .doc(goal["id"])
            .delete();

        print("Goal completed and deleted: ${goal['title']}");
      }
    }

    // Add new goals if needed
    if (accEventsPerMinute > 0.2) {
      final goal = {
        "vehicleId": _vehicleId,
        "title": "Improve Smooth Throttle",
        "description": "Reduce harsh acceleration in your next trips.",
        "createdAt": FieldValue.serverTimestamp(),
        "target":
        "Drive with fewer than ${(durationMinutes * 0.2).toStringAsFixed(0)} harsh events",
      };

      if (!goalExists(currentGoals, goal)) {
        await firestore
            .collection("users")
            .doc(_userId)
            .collection("goals")
            .add(goal);
        print("New goal generated: ${goal['title']}");
      }
    }

    if (brEventsPerMinute > 0.2) {
      final goal = {
        "vehicleId": _vehicleId,
        "title": "Improve Smooth Braking",
        "description": "Reduce harsh braking in your next trips.",
        "createdAt": FieldValue.serverTimestamp(),
        "target":
        "Drive with fewer than ${(durationMinutes * 0.2).toStringAsFixed(0)} harsh events",
      };

      if (!goalExists(currentGoals, goal)) {
        await firestore
            .collection("users")
            .doc(_userId)
            .collection("goals")
            .add(goal);
        print("New goal generated: ${goal['title']}");
      }
    }
  }

  bool goalExists(
      List<Map<String, dynamic>> goals,
      Map<String, dynamic> newGoal,
      ) {
    return goals.any(
          (goal) =>
      goal["title"] == newGoal["title"] &&
          goal["vehicleId"] == newGoal["vehicleId"],
    );
  }
}