import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:raxxy/services/crash_detector.dart';
import 'package:raxxy/services/monitoring_service/session_summary_service.dart';
import 'package:raxxy/services/monitoring_service/driving_score_service.dart';
import 'package:raxxy/services/monitoring_service/goal_generation_service.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../providers/provider.dart';
import '../../providers/safety_feature_provider.dart';
import '../notifications_services.dart';

class VehicleMonitorService {
  final ValueNotifier<String?> monitoredVehicleIdNotifier = ValueNotifier(null);
  final ValueNotifier<double> currentSpeedNotifier = ValueNotifier(0.0);
  final ValueNotifier<double> currentAccelerationNotifier = ValueNotifier(0.0);
  final ValueNotifier<double> currentDistanceNotifier = ValueNotifier(0.0);

  static final VehicleMonitorService _instance =
  VehicleMonitorService._internal();

  factory VehicleMonitorService() => _instance;

  VehicleMonitorService._internal();

  // Service instances
  final SessionSummaryService _sessionService = SessionSummaryService();

  StreamSubscription<UserAccelerometerEvent>? _accelSub;
  StreamSubscription<Position>? _positionSub;
  Timer? _uiUpdateTimer;
  Timer? _speedZoneTimer; // NEW: For tracking speed zones every second

  UserAccelerometerEvent? currentAcceleration;
  double currentSpeedKmh = 0.0;

  final List<Map<String, dynamic>> _speedHistory = [];

  double totalDistanceMeters = 0.0;
  Position? _lastPosition;

  bool _isMonitoring = false;

  // Threshold values
  final double accelerationThreshold = 2.0;

  final List<double> _accelBuffer = [];
  final int _acBufferSize = 10;

  // Filtering parameters
  final double minSpeedThreshold = 0.0;
  final int sustainedSampleCount = 1;
  final double jitterThreshold = 2.0;

  String? _userId;
  String? _vehicleId;

  // Notification cooldown
  DateTime? _lastHarshAccelNotification;
  DateTime? _lastHarshBrakeNotification;
  final Duration _notificationCooldown = const Duration(seconds: 5);

  // Crash detection cooldown
  DateTime? _lastCrashDetection;
  final Duration _crashCooldown = const Duration(seconds: 10);

  // Tracking variables for sustained events
  int _consecutiveHarshAccel = 0;
  int _consecutiveHarshBrake = 0;

  // Store BuildContext for scaffold messages
  BuildContext? _monitoringContext;

  // ==================== TURN DETECTION VARIABLES ====================

  double? _lastAccelX;
  double? _lastAccelY;

  final double turnAngleThreshold = 15.0;

  DateTime? _lastTurnDetection;
  final Duration _turnCooldown = const Duration(seconds: 2);

  final double minSpeedForTurnDetection = 10.0;

  // ==================== ACCELERATION/DECELERATION DETECTION ====================

  double? _lastDirectionX;
  double? _lastDirectionY;
  double? _lastDirectionZ;

  bool _isDecelerating = false;

  final double magnitudeSettledThreshold = 0.5;
  final double directionReversalThreshold = 160.0;

  // =================================================================================

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
    _monitoringContext = context;

    // Start session tracking
    _sessionService.startSession();

    // Reset crash detection
    _lastCrashDetection = null;

    // Reset consecutive counters
    _consecutiveHarshAccel = 0;
    _consecutiveHarshBrake = 0;

    // Reset turn detection variables
    _lastAccelX = null;
    _lastAccelY = null;
    _lastTurnDetection = null;

    // Reset acceleration/deceleration variables
    _lastDirectionX = null;
    _lastDirectionY = null;
    _lastDirectionZ = null;
    _isDecelerating = false;

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

    // Start UI update timer
    _uiUpdateTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (_accelBuffer.isNotEmpty) {
        double avgAccel =
            _accelBuffer.reduce((a, b) => a + b) / _accelBuffer.length;
        ref.read(vehicleMonitorProvider.notifier).updateAcceleration(avgAccel);
      }
      ref.read(vehicleMonitorProvider.notifier).updateSpeed(currentSpeedKmh);
      ref.read(vehicleMonitorProvider.notifier).updateDistance(totalDistanceMeters);

      // Update session speed tracking
      _sessionService.updateSpeed(currentSpeedKmh);
    });

    // ACCELEROMETER LOGIC
    _accelSub = userAccelerometerEvents.listen((event) {
      currentAcceleration = event;

      // TURN DETECTION
      _detectTurn(event.x, event.y);

      // ==================== ACCELERATION/DECELERATION LOGIC ====================

      // 1. Calculate magnitude from all 3 axes
      double magnitude = sqrt(
          event.x * event.x +
              event.y * event.y +
              event.z * event.z
      );

      // 2. Detect direction reversal
      _detectDirectionReversal(event.x, event.y, event.z, magnitude);

      // 3. Apply sign based on deceleration flag
      double signedAcceleration = _isDecelerating ? -magnitude : magnitude;

      // =============================================================================

      _accelBuffer.add(signedAcceleration);
      if (_accelBuffer.length > _acBufferSize) {
        _accelBuffer.removeAt(0);
      }

      // Only check for harsh events if buffer is full AND vehicle is moving
      if (_accelBuffer.length == _acBufferSize &&
          currentSpeedKmh > minSpeedThreshold) {

        // Calculate average signed acceleration
        double avgAccel =
            _accelBuffer.reduce((a, b) => a + b) / _accelBuffer.length;

        // ==================== USE ABSOLUTE VALUE FOR DETECTION ====================

        // Get magnitude (absolute value) for threshold comparison
        double avgMagnitude = avgAccel.abs();

        // Calculate standard deviation using MAGNITUDE
        double variance = 0;
        for (double val in _accelBuffer) {
          variance += pow(val.abs() - avgMagnitude, 2);
        }
        double stdDev = sqrt(variance / _accelBuffer.length);

        // If too much jitter/noise, skip detection
        if (stdDev > jitterThreshold) {
          _consecutiveHarshAccel = 0;
          _consecutiveHarshBrake = 0;
          return;
        }

        // Check if magnitude exceeds threshold
        if (avgMagnitude > accelerationThreshold) {
          // Determine if it's acceleration or braking based on SIGN
          if (avgAccel > 0) {
            // Positive = Acceleration
            _consecutiveHarshAccel++;
            _consecutiveHarshBrake = 0;

            // Track state change for session service
            _sessionService.updateAccelDecelState("accel");

            if (_consecutiveHarshAccel >= sustainedSampleCount) {
              if (_shouldSendNotification(_lastHarshAccelNotification)) {
                _sessionService.incrementHarshAccel();
                _lastHarshAccelNotification = DateTime.now();
                sendNotification(
                  "Woah Buddy! Easy on the Gas",
                  "Acceleration: ${avgMagnitude.toStringAsFixed(2)} m/s² at ${currentSpeedKmh.toStringAsFixed(0)} km/h",
                );
                print("🟢 Harsh ACCELERATION detected: ${avgMagnitude.toStringAsFixed(2)} m/s²");
                _consecutiveHarshAccel = 0;
              }
            }
          } else {
            // Negative = Braking
            _consecutiveHarshBrake++;
            _consecutiveHarshAccel = 0;

            // Track state change for session service
            _sessionService.updateAccelDecelState("decel");

            if (_consecutiveHarshBrake >= sustainedSampleCount) {
              if (_shouldSendNotification(_lastHarshBrakeNotification)) {
                _sessionService.incrementHarshBrake();
                _lastHarshBrakeNotification = DateTime.now();
                sendNotification(
                  "Woah Buddy! Easy on the Brakes",
                  "Deceleration: ${avgMagnitude.toStringAsFixed(2)} m/s² at ${currentSpeedKmh.toStringAsFixed(0)} km/h",
                );
                print("🔴 Harsh BRAKING detected: ${avgMagnitude.toStringAsFixed(2)} m/s²");
                _consecutiveHarshBrake = 0;
              }
            }
          }
        } else {
          // Reset counters if magnitude is below threshold
          _consecutiveHarshAccel = 0;
          _consecutiveHarshBrake = 0;

          // Track neutral state
          _sessionService.updateAccelDecelState("neutral");
        }

        // ====================================================================================

        // Check for crash
        if (crashFeature == true) {
          _checkCrashFromAcceleration(context, ref, avgMagnitude);
        }
      } else if (currentSpeedKmh <= minSpeedThreshold) {
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

      // Store speed history for crash detection
      _speedHistory.add({'time': now, 'speed': currentSpeedKmh});
      if (_speedHistory.length > 10) _speedHistory.removeAt(0);

      // Check for sudden speed drop
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

    print('✅ Monitoring started with enhanced analytics');
  }

  // ==================== DIRECTION REVERSAL DETECTION ====================

  void _detectDirectionReversal(double currentX, double currentY, double currentZ, double magnitude) {
    if (_lastDirectionX == null || _lastDirectionY == null || _lastDirectionZ == null) {
      _lastDirectionX = currentX;
      _lastDirectionY = currentY;
      _lastDirectionZ = currentZ;
      return;
    }

    if (magnitude < magnitudeSettledThreshold) {
      _isDecelerating = false;
      _lastDirectionX = currentX;
      _lastDirectionY = currentY;
      _lastDirectionZ = currentZ;
      return;
    }

    double dotProduct = (_lastDirectionX! * currentX) +
        (_lastDirectionY! * currentY) +
        (_lastDirectionZ! * currentZ);

    double lastMagnitude = sqrt(
        _lastDirectionX! * _lastDirectionX! +
            _lastDirectionY! * _lastDirectionY! +
            _lastDirectionZ! * _lastDirectionZ!
    );

    if (lastMagnitude < 0.01) {
      _lastDirectionX = currentX;
      _lastDirectionY = currentY;
      _lastDirectionZ = currentZ;
      return;
    }

    double cosTheta = dotProduct / (lastMagnitude * magnitude);
    cosTheta = cosTheta.clamp(-1.0, 1.0);

    double angleRadians = acos(cosTheta);
    double angleDegrees = angleRadians * (180 / pi);

    if (angleDegrees > directionReversalThreshold) {
      if (!_isDecelerating) {
        print("🔴 Direction Reversal Detected: ${angleDegrees.toStringAsFixed(1)}° - DECELERATION mode");
      }
      _isDecelerating = true;
    } else if (magnitude < magnitudeSettledThreshold) {
      if (_isDecelerating) {
        print("🟢 Acceleration Settled - ACCELERATION mode");
      }
      _isDecelerating = false;
    }

    _lastDirectionX = currentX;
    _lastDirectionY = currentY;
    _lastDirectionZ = currentZ;
  }

  // ==================== TURN DETECTION ====================

  void _detectTurn(double currentX, double currentY) {
    if (currentSpeedKmh < minSpeedForTurnDetection) {
      _lastAccelX = currentX;
      _lastAccelY = currentY;
      return;
    }

    if (_lastTurnDetection != null &&
        DateTime.now().difference(_lastTurnDetection!) < _turnCooldown) {
      return;
    }

    if (_lastAccelX == null || _lastAccelY == null) {
      _lastAccelX = currentX;
      _lastAccelY = currentY;
      return;
    }

    double lastAngle = atan2(_lastAccelY!, _lastAccelX!);
    double currentAngle = atan2(currentY, currentX);

    double angleDifference = currentAngle - lastAngle;

    while (angleDifference > pi) angleDifference -= 2 * pi;
    while (angleDifference < -pi) angleDifference += 2 * pi;

    double angleDifferenceInDegrees = angleDifference * (180 / pi);

    if (angleDifferenceInDegrees.abs() > turnAngleThreshold) {
      String turnDirection;
      if (angleDifferenceInDegrees > 0) {
        turnDirection = "Left";
        _sessionService.incrementLeftTurn();
      } else {
        turnDirection = "Right";
        _sessionService.incrementRightTurn();
      }

      print(
          "🔄 Turn Detected: $turnDirection turn "
              "(${angleDifferenceInDegrees.abs().toStringAsFixed(1)}° at ${currentSpeedKmh.toStringAsFixed(0)} km/h)"
      );

      _lastTurnDetection = DateTime.now();
    }

    _lastAccelX = currentX;
    _lastAccelY = currentY;
  }

  // ==================== HELPER METHODS ====================

  bool _shouldSendNotification(DateTime? lastNotification) {
    if (lastNotification == null) return true;
    return DateTime.now().difference(lastNotification) > _notificationCooldown;
  }

  void _checkCrashFromAcceleration(
      BuildContext context,
      WidgetRef ref,
      double avgMagnitude,
      ) {
    if (_lastCrashDetection != null &&
        DateTime.now().difference(_lastCrashDetection!) < _crashCooldown) {
      return;
    }

    if (_accelBuffer.length < 2) return;

    double accelFluctuation =
        _accelBuffer[_accelBuffer.length - 1].abs() -
            _accelBuffer[_accelBuffer.length - 2].abs();

    if (accelFluctuation.abs() > 1) {
      _triggerCrashDetection(context, ref);
    }
  }

  void _checkCrashFromSpeedDrop(BuildContext context, WidgetRef ref) {
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

    if (delSpeed < -15 && delTime < 1.5) {
      _triggerCrashDetection(context, ref);
    }
  }

  void _triggerCrashDetection(BuildContext context, WidgetRef ref) {
    _lastCrashDetection = DateTime.now();
    print("CRASH DETECTED - Triggering crash protocol");

    sendNotification("Crash Detected", "Possible impact detected");

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        CrashDetector.checkForCrash(
          context,
          ref,
          onDialogClosed: () {
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
    _speedZoneTimer?.cancel();

    _lastPosition = null;
    _isMonitoring = false;

    try {
      await WakelockPlus.disable();
      print('Wakelock disabled - screen may sleep now');
    } catch (e) {
      print('Failed to disable wakelock: $e');
    }

    if (_userId != null && _vehicleId != null) {
      try {
        final firestore = FirebaseFirestore.instance;
        final vehicleDoc = firestore
            .collection('users')
            .doc(_userId)
            .collection('vehicles')
            .doc(_vehicleId);

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

        await Future.delayed(const Duration(milliseconds: 500));

        // Save session summary
        await _sessionService.saveSummary(
          userId: _userId!,
          vehicleId: _vehicleId!,
          totalDistanceKm: totalDistanceMeters / 1000,
        );

        if (_monitoringContext != null && _monitoringContext!.mounted) {
          final summary = _sessionService.generateSummary(totalDistanceMeters / 1000);
          ScaffoldMessenger.of(_monitoringContext!).showSnackBar(
            SnackBar(
              content: Text(
                '💾 Trip summary saved (${summary['durationMinutes']} min, ${(totalDistanceMeters / 1000).toStringAsFixed(1)} km)',
              ),
              backgroundColor: Colors.blue,
              duration: const Duration(seconds: 2),
            ),
          );
        }

        await Future.delayed(const Duration(milliseconds: 500));

        // Update driving score
        final summary = _sessionService.generateSummary(totalDistanceMeters / 1000);
        await DrivingScoreService.updateDrivingScore(
          userId: _userId!,
          harshAccelEvents: _sessionService.harshAccelEvents,
          harshBrakeEvents: _sessionService.harshBrakeEvents,
          sessionDurationMinutes: summary['durationMinutes'],
        );

        if (_monitoringContext != null && _monitoringContext!.mounted) {
          ScaffoldMessenger.of(_monitoringContext!).showSnackBar(
            SnackBar(
              content: Text(
                '📊 Driving score updated (${_sessionService.harshAccelEvents} harsh accel, ${_sessionService.harshBrakeEvents} harsh brakes)',
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 2),
            ),
          );
        }

        await Future.delayed(const Duration(milliseconds: 500));

        // Generate goals
        await GoalsGenerationService.generateGoals(
          userId: _userId!,
          vehicleId: _vehicleId!,
          harshAccelEvents: _sessionService.harshAccelEvents,
          harshBrakeEvents: _sessionService.harshBrakeEvents,
          sessionDurationMinutes: summary['durationMinutes'],
        );

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
    _monitoringContext = null;
    print('Monitoring stopped');
  }
}