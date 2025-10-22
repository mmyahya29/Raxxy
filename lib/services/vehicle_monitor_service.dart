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
import 'notifications_services.dart';

class VehicleMonitorService {
  final ValueNotifier<String?> monitoredVehicleIdNotifier = ValueNotifier(null);
  final ValueNotifier<double> currentSpeedNotifier = ValueNotifier(0.0);
  final ValueNotifier<double> currentAccelerationNotifier = ValueNotifier(0.0);
  final ValueNotifier<double> currentDistanceNotifier = ValueNotifier(0.0);

  static final VehicleMonitorService _instance = VehicleMonitorService._internal();
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

  final double accelerationThreshold = 1.5;
  final double decelerationThreshold = -1.5;

  final List<double> _accelBuffer = [];
  final int _acBufferSize = 10;

  String? _userId;
  String? _vehicleId;

  // Notification cooldown
  DateTime? _lastHarshAccelNotification;
  DateTime? _lastHarshBrakeNotification;
  final Duration _notificationCooldown = const Duration(seconds: 5);

  // Variables for session summary
  DateTime? _sessionStart;
  DateTime? _sessionEnd;

  double _maxSpeed = 0.0;
  double _speedSum = 0.0;
  int _speedCount = 0;

  int _harshAccelEvents = 0;
  int _harshBrakeEvents = 0;

  // Crash detection state
  bool _crashDetectionTriggered = false;
  DateTime? _lastCrashDetection;
  final Duration _crashCooldown = const Duration(seconds: 30); // 30 second cooldown between crashes

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

    // Session summary values reset
    _sessionStart = DateTime.now();
    _sessionEnd = null;
    _maxSpeed = 0.0;
    _speedSum = 0.0;
    _speedCount = 0;
    _harshAccelEvents = 0;
    _harshBrakeEvents = 0;
    _crashDetectionTriggered = false;

    ref.read(vehicleMonitorProvider.notifier).setVehicle(vehicleId);
    ref.read(vehicleMonitorProvider.notifier).setMake(make);
    ref.read(vehicleMonitorProvider.notifier).setModel(model);

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
        double avgAccel = _accelBuffer.reduce((a, b) => a + b) / _accelBuffer.length;
        ref.read(vehicleMonitorProvider.notifier).updateAcceleration(avgAccel);
      }
      ref.read(vehicleMonitorProvider.notifier).updateSpeed(currentSpeedKmh);
      ref.read(vehicleMonitorProvider.notifier).updateDistance(totalDistanceMeters);
    });

    _accelSub = userAccelerometerEvents.listen((event) {
      currentAcceleration = event;

      // Simplified horizontal acceleration calculation
      double horizontalAccel = sqrt(event.x * event.x + event.y * event.y);

      // Determine direction based on dominant axis
      if (event.y < 0) {
        horizontalAccel *= -1; // Negative for deceleration
      }

      _accelBuffer.add(horizontalAccel);
      if (_accelBuffer.length > _acBufferSize) {
        _accelBuffer.removeAt(0);
      }

      // Only check for harsh events if buffer is full
      if (_accelBuffer.length == _acBufferSize) {
        double avgAccel = _accelBuffer.reduce((a, b) => a + b) / _accelBuffer.length;

        // Harsh acceleration check with cooldown
        if (avgAccel > accelerationThreshold) {
          _harshAccelEvents++;
          if (_shouldSendNotification(_lastHarshAccelNotification)) {
            _lastHarshAccelNotification = DateTime.now();
            sendNotification(
                "Woah Buddy! Easy on the Gas",
                "Acceleration: ${avgAccel.toStringAsFixed(2)} m/s²"
            );
          }
        }
        // Harsh braking check with cooldown
        else if (avgAccel < decelerationThreshold) {
          _harshBrakeEvents++;
          if (_shouldSendNotification(_lastHarshBrakeNotification)) {
            _lastHarshBrakeNotification = DateTime.now();
            sendNotification(
                "Woah Buddy! Easy on the Brakes",
                "Deceleration: ${avgAccel.toStringAsFixed(2)} m/s²"
            );
          }
        }

        // Check for crash - high acceleration fluctuation
        _checkCrashFromAcceleration(context, avgAccel);
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
      _speedHistory.add({
        'time': now,
        'speed': currentSpeedKmh,
      });
      if (_speedHistory.length > 10) _speedHistory.removeAt(0);

      // Check for sudden speed drop (crash detection)
      if (_speedHistory.length >= 2) {
        _checkCrashFromSpeedDrop(context);
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

    print('Monitoring started');
  }

  bool _shouldSendNotification(DateTime? lastNotification) {
    if (lastNotification == null) return true;
    return DateTime.now().difference(lastNotification) > _notificationCooldown;
  }

  void _checkCrashFromAcceleration(BuildContext context, double avgAccel) {
    if (_crashDetectionTriggered) return;

    // Calculate acceleration fluctuation
    if (_accelBuffer.length < 2) return;

    double accelFluctuation = _accelBuffer[_accelBuffer.length-1]-_accelBuffer[_accelBuffer.length-2];
    // for (int i = 0; i < _accelBuffer.length - 1; i++) {
    //   accelFluctuation += (_accelBuffer[i] - _accelBuffer[i + 1]).abs();
    // }

    // If high jitter/fluctuation detected
    if (accelFluctuation.abs() > 1) {
      _triggerCrashDetection(context);
    }
  }

  void _checkCrashFromSpeedDrop(BuildContext context) {
    if (_crashDetectionTriggered) return;
    if (_speedHistory.length < 2) return;

    final recent = _speedHistory[_speedHistory.length - 1];
    final previous = _speedHistory[_speedHistory.length - 2];

    final delTime = recent['time'].difference(previous['time']).inMilliseconds / 1000.0;
    final delSpeed = recent['speed'] - previous['speed'];

    // Sudden speed drop > 15 km/h in < 1.5 seconds
    if (delSpeed < -15 && delTime < 1.5) {
      _triggerCrashDetection(context);
    }
  }

  void _triggerCrashDetection(BuildContext context) {
    // Check cooldown to prevent crash spam
    if (_lastCrashDetection != null &&
        DateTime.now().difference(_lastCrashDetection!) < _crashCooldown) {
      print("Crash detection cooldown active - ignoring trigger");
      return;
    }

    _crashDetectionTriggered = true;
    _lastCrashDetection = DateTime.now();
    print("CRASH DETECTED - Triggering crash protocol");

    sendNotification("Crash Detected", "Possible impact detected");

    // Run crash detection on next frame to avoid blocking
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        CrashDetector.checkForCrash(
          context,
          onDialogClosed: () {
            // Reset crash detection flag after user responds
            print("Crash dialog closed - resetting crash detection flag");
            _crashDetectionTriggered = false;
          },
        );
      }
    });
  }

  Future<void> stopMonitoring(WidgetRef ref) async {
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

    // Update mileage ONCE when stopping (instead of every GPS update)
    await _updateVehicleMileageOnStop(totalDistanceMeters);

    // Generate goals based on session
    await generateGoalFromSummary(summary);

    // Calculate driving score
    await calculateDrivingScore(
      avgSpeed: summary["avgSpeed"],
      harshAccel: summary["harshAccelerations"],
      harshBrakes: summary["harshBrakes"],
      durationMinutes: summary["duration"],
    );

    // Save summary to Firestore
    final firestore = FirebaseFirestore.instance;
    await firestore
        .collection('users')
        .doc(_userId)
        .collection('sessions')
        .add(summary);

    // Reset distance
    totalDistanceMeters = 0.0;

    ref.read(vehicleMonitorProvider.notifier).clear();

    print('Monitoring stopped');
    sendNotification("RAXXY", "Monitoring service stopped");
  }

  Future<void> _updateVehicleMileageOnStop(double totalDistanceMeters) async {
    if (_userId == null || _vehicleId == null) return;

    final firestore = FirebaseFirestore.instance;
    final docRef = firestore
        .collection('users')
        .doc(_userId)
        .collection('vehicles')
        .doc(_vehicleId);

    try {
      final snapshot = await docRef.get();
      if (!snapshot.exists) return;

      double currentMileage = snapshot['mileage']?.toDouble() ?? 0.0;
      double distanceKm = totalDistanceMeters / 1000.0;

      await docRef.update({'mileage': currentMileage + distanceKm});
      print('Mileage updated: +${distanceKm.toStringAsFixed(2)} km');
    } catch (e) {
      print('Error updating mileage: $e');
    }
  }

  Map<String, dynamic> generateSessionSummary() {
    _sessionEnd = DateTime.now();

    double avgSpeed = _speedCount > 0 ? _speedSum / _speedCount : 0.0;
    double distanceKm = totalDistanceMeters / 1000.0;
    Duration duration = _sessionEnd!.difference(_sessionStart!);

    return {
      "startTime": _sessionStart,
      "endTime": _sessionEnd,
      "duration": duration.inMinutes,
      "distanceKm": distanceKm,
      "maxSpeed": _maxSpeed,
      "avgSpeed": avgSpeed,
      "harshAccelerations": _harshAccelEvents,
      "harshBrakes": _harshBrakeEvents,
    };
  }

  Future<void> generateGoalFromSummary(Map<String, dynamic> summary) async {
    final firestore = FirebaseFirestore.instance;
    final userId = _userId;

    List<Map<String, dynamic>> currentGoals = [];

    try {
      final querySnapshot = await firestore
          .collection('users')
          .doc(userId)
          .collection('goals')
          .get();

      currentGoals = querySnapshot.docs
          .map((doc) => {
        'id': doc.id,
        ...doc.data(),
      })
          .toList();

      print("Fetched ${currentGoals.length} goals for user $userId");
    } catch (e) {
      print("Error fetching goals: $e");
      return;
    }

    final int accHarshEvents = (summary["harshAccelerations"] ?? 0);
    final int brHarshEvents = (summary["harshBrakes"] ?? 0);
    final int durationMinutes = summary["duration"] ?? 0;

    if (durationMinutes == 0) return;

    double accEventsPerMinute = accHarshEvents / durationMinutes;
    double brEventsPerMinute = brHarshEvents / durationMinutes;

    // Delete completed goals
    for (var goal in currentGoals) {
      bool shouldDelete = false;

      if (goal["title"] == "Improve Smooth Throttle" && accEventsPerMinute < 0.2) {
        shouldDelete = true;
      } else if (goal["title"] == "Improve Smooth Braking" && brEventsPerMinute < 0.2) {
        shouldDelete = true;
      }

      if (shouldDelete) {
        await firestore
            .collection('users')
            .doc(userId)
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
        "target": "Drive with fewer than ${(durationMinutes * 0.2).toStringAsFixed(0)} harsh events",
      };

      if (!goalExists(currentGoals, goal)) {
        await firestore.collection("users").doc(userId).collection("goals").add(goal);
        print("New goal generated: ${goal['title']}");
      }
    }

    if (brEventsPerMinute > 0.2) {
      final goal = {
        "vehicleId": _vehicleId,
        "title": "Improve Smooth Braking",
        "description": "Reduce harsh braking in your next trips.",
        "createdAt": FieldValue.serverTimestamp(),
        "target": "Drive with fewer than ${(durationMinutes * 0.2).toStringAsFixed(0)} harsh events",
      };

      if (!goalExists(currentGoals, goal)) {
        await firestore.collection("users").doc(userId).collection("goals").add(goal);
        print("New goal generated: ${goal['title']}");
      }
    }
  }

  bool goalExists(List<Map<String, dynamic>> goals, Map<String, dynamic> newGoal) {
    return goals.any((g) =>
    g["title"] == newGoal["title"] && g["vehicleId"] == newGoal["vehicleId"]);
  }

  Future<void> calculateDrivingScore({
    required double avgSpeed,
    required int harshAccel,
    required int harshBrakes,
    required int durationMinutes,
  }) async {
    final firestore = FirebaseFirestore.instance;
    final userId = _userId;
    if (userId == null) return;

    double sessionScore = 100.0;

    // Penalize harsh events
    int totalHarshEvents = harshAccel + harshBrakes;
    sessionScore -= totalHarshEvents * 2;

    // Penalize unsafe speeds
    if (avgSpeed > 100) {
      sessionScore -= (avgSpeed - 100) * 0.5;
    } else if (avgSpeed < 20) {
      sessionScore -= (20 - avgSpeed) * 0.3;
    }

    // Reward for longer trips
    if (durationMinutes > 30) {
      sessionScore += 3;
    } else if (durationMinutes < 5) {
      sessionScore -= 5;
    }

    sessionScore = sessionScore.clamp(0, 100);

    // Get current score
    final userDoc = firestore.collection('users').doc(userId);
    final snapshot = await userDoc.get();
    double currentScore = (snapshot.data()?['drivingScore'] ?? 50).toDouble();

    // Weighted update
    double newGlobalScore = currentScore + (sessionScore - 50) * 0.1;
    newGlobalScore = newGlobalScore.clamp(0, 100);

    await userDoc.set({'drivingScore': newGlobalScore}, SetOptions(merge: true));

    print('Session Score: $sessionScore');
    print('Updated Global Driving Score: $newGlobalScore');
  }

  bool get isMonitoring => _isMonitoring;
}