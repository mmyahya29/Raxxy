import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:raxxy/services/crash_detector.dart';
import 'package:raxxy/services/monitoring_service/session_summary_service.dart';
import 'package:raxxy/services/monitoring_service/driving_score_service.dart';
import 'package:raxxy/services/monitoring_service/goal_generation_service.dart';
import 'package:raxxy/services/driver_profile_service.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../providers/provider.dart';
import '../../providers/safety_feature_provider.dart';
import '../notifications_services.dart';
import 'package:raxxy/services/monitoring_service/feedback_service.dart';


class VehicleMonitorService {

  // ==============================================================================
  // 🔧 SENSITIVITY & TESTING CONFIGURATION (CHANGE THESE FOR TESTING)
  // ==============================================================================

  // --- GENERAL THRESHOLDS ---
  // Minimum speed to consider the car "moving" for event detection
  static const double _kMinSpeedThresholdKmh = 0.0; // Default: 10.0 (Lowered for testing)

  // --- ACCELERATION & BRAKING ---
  // G-Force required to trigger Harsh Acceleration/Braking
  // 1 G = 9.8 m/s². 2.0 m/s² is approx 0.2G (mild).
  // For hard testing, keep this low. For production, raise to ~2.5 - 3.0.
  static const double _kAccelerationThreshold = 1.8;

  // How much "jitter" (noise) allowed before we discard the data
  static const double _kJitterThreshold = 2.0;

  // --- TURNING SENSITIVITY ---
  // Lateral force (m/s²) required to detect a turn
  static const double _kTurnForceThreshold = 1.5; // Default: 2.0 (Lowered for sensitivity)
  // How long (ms) a lateral force must exist to be a "turn" and not a lane change
  static const int _kTurnDurationMs = 500; // Default: 700 (Shortened for easier detection)
  // Smoothing factor for lateral force (0.0 = infinite smoothing, 1.0 = raw data)
  static const double _kLpfAlpha = 0.15;

  // --- GYROSCOPE ---
  // Minimum rotation rate (rad/s) to confirm a turn
  static const double _kGyroRotationThreshold = 0.3; // Default: 0.5

  // --- TURN QUALITY SCORING ---
  // Below this lateral force, a turn is "Smooth"
  static const double _kSmoothTurnLimit = 3.0;
  // Above this lateral force, a turn is "Jerky"
  static const double _kJerkyTurnLimit = 5.0;
  // If speed drops by this much (km/h) during a turn, it's "Jerky"
  static const double _kSignificantSpeedDrop = 12.0;

  // --- CRASH DETECTION ---
  // Immediate change in acceleration (jerk) to suspect a crash
  static const double _kCrashAccelFluctuationLimit = 1.0;
  // Speed drop (km/h) within 1.5 seconds to suspect a crash
  static const double _kCrashSpeedDropLimit = -15.0;

  // --- COOLDOWN TIMERS (Hardcoded for crucial testing flow) ---
  // Time between Harsh Event Notifications
  static const Duration _kNotificationCooldown = Duration(seconds: 3); // Default: 5s
  // Time between detecting separate Turns
  static const Duration _kTurnCooldown = Duration(seconds: 1); // Default: 2s
  // Time between Crash triggers
  static const Duration _kCrashCooldown = Duration(seconds: 10);

  // ==============================================================================
  // END OF CONFIGURATION
  // ==============================================================================

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
  final CoachingService _coachingService = CoachingService();
  final FeedbackService _feedbackService = FeedbackService();


  StreamSubscription<UserAccelerometerEvent>? _accelSub;
  StreamSubscription<Position>? _positionSub;
  Timer? _uiUpdateTimer;
  Timer? _speedZoneTimer;

  UserAccelerometerEvent? currentAcceleration;
  double currentSpeedKmh = 0.0;

  final List<Map<String, dynamic>> _speedHistory = [];

  double totalDistanceMeters = 0.0;
  Position? _lastPosition;

  bool _isMonitoring = false;

  final List<double> _accelBuffer = [];
  final int _acBufferSize = 5;    //================Buffer for smoothness===================
  final int sustainedSampleCount = 1;

  String? _userId;
  String? _vehicleId;

  // Notification cooldown
  DateTime? _lastHarshAccelNotification;
  DateTime? _lastHarshBrakeNotification;

  // Crash detection cooldown
  DateTime? _lastCrashDetection;

  // Tracking variables for sustained events
  int _consecutiveHarshAccel = 0;
  int _consecutiveHarshBrake = 0;

  // Store BuildContext for scaffold messages
  BuildContext? _monitoringContext;

  // ==================== TRIGGER TRACKING ====================
  bool _hasWarnedAboutTimeTrigger = false;
  List<String> _activeTriggers = [];
  int _lowSpeedCounter = 0;

  // ==================== TURN DETECTION VARIABLES ====================
  // Low-pass filter for smoothing lateral force
  double _smoothedLateralForce = 0.0;

  // State tracking
  DateTime? _turnStartTime;
  DateTime? _lastTurnDetection;

  // Turn Quality
  double? _turnEntrySpeed;
  double _turnPeakForce = 0.0;

  // GYROSCOPE VARIABLES
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  double _smoothedGyroZ = 0.0;
  final bool _useGyroscopeFusion = true;

  // ACCELERATION/DECELERATION DETECTION
  double? _lastDirectionX;
  double? _lastDirectionY;
  double? _lastDirectionZ;

  bool _isDecelerating = false;

  final double magnitudeSettledThreshold = 0.5;
  final double directionReversalThreshold = 160.0;

  Future<void> startMonitoring({
    required BuildContext context,
    required String userId,
    required String vehicleId,
    required String make,
    required String model,
    required WidgetRef ref,
  }) async {
    // Reset turn detection variables
    _smoothedLateralForce = 0.0;
    _turnStartTime = null;
    _lastTurnDetection = null;

    // Reset trigger tracking
    _hasWarnedAboutTimeTrigger = false;
    _activeTriggers = [];
    _lowSpeedCounter = 0;

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
    debugPrint("RAXXY : Monitoring service started");


    // Check for stress triggers immediately at start
    _checkStressTriggers(userId);

    try {
      await WakelockPlus.enable();
      print('Wakelock enabled - screen will stay on while monitoring');
    } catch (e) {
      print('Failed to enable wakelock: $e');
    }

    // Initialize Feedback Service with history
    await _feedbackService.initialize(userId);
    _feedbackService.evaluateWeather(ref);

    // Start UI update timer
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

      // Update session speed tracking
      _sessionService.updateSpeed(currentSpeedKmh);

      // Dynamic Traffic Monitor check
      if (_activeTriggers.contains('Heavy Traffic')) {
        if (currentSpeedKmh < 30 && currentSpeedKmh > 0) {
          _lowSpeedCounter++;
          // If in low speed for ~5 minutes (600 * 0.5s = 300s)
          if (_lowSpeedCounter > 600) {
            _triggerPreventativeAlert(
                "Traffic Detected",
                "We know heavy traffic stresses you out. Stay cool!"
            );
            _lowSpeedCounter = -600; // Reset with delay to avoid spam
          }
        } else {
          _lowSpeedCounter = 0;
        }
      }
    });

    // ACCELEROMETER LOGIC
    _accelSub = userAccelerometerEvents.listen((event) {
      currentAcceleration = event;

      // TURN DETECTION
      _detectTurn(event.x);

      // ==================== ACCELERATION/DECELERATION LOGIC ====================

      // 1. Calculate magnitude from all 3 axes
      double magnitude = sqrt(
        event.x * event.x + event.y * event.y + event.z * event.z,
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
          currentSpeedKmh > _kMinSpeedThresholdKmh) {
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
        if (stdDev > _kJitterThreshold) {
          _consecutiveHarshAccel = 0;
          _consecutiveHarshBrake = 0;
          return;
        }

        // Check if magnitude exceeds threshold
        if (avgMagnitude > _kAccelerationThreshold) {
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

                // COACHING: Voice + Haptic Feedback for Accel
                // DEPRECATED: Handled by FeedbackService now, but keeping for backup until verified
                // Old direct call: _coachingService.triggerFeedback(...)
                
                // NEW: Use FeedbackService
                _feedbackService.evaluateAcceleration(avgMagnitude, currentSpeedKmh);


                debugPrint(
                  "🟢 Harsh ACCELERATION detected: ${avgMagnitude.toStringAsFixed(2)} m/s²",
                );
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

                // COACHING: Voice + Haptic Feedback for Brake
                // NEW: Use FeedbackService
                _feedbackService.evaluateBraking(avgMagnitude, currentSpeedKmh);


                print(
                  "🔴 Harsh BRAKING detected: ${avgMagnitude.toStringAsFixed(2)} m/s²",
                );
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
      } else if (currentSpeedKmh <= _kMinSpeedThresholdKmh) {
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

    // ==================== GYROSCOPE LISTENER ====================
    if (_useGyroscopeFusion) {
      _gyroSub = gyroscopeEvents.listen((GyroscopeEvent event) {
        // Smooth the Z-axis rotation (yaw - turning left/right)
        _smoothedGyroZ =
            (_kLpfAlpha * event.z) + ((1 - _kLpfAlpha) * _smoothedGyroZ);
      });
      print('✅ Gyroscope fusion enabled for turn detection');
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

  // ==================== TRIGGER CHECKING ====================

  Future<void> _checkStressTriggers(String userId) async {
    try {
      // 1. Get cached profile (fastest)
      final profile = await DriverProfileService.getCachedProfile(userId);
      if (profile == null) return;

      final triggers = List<String>.from(profile['stressTriggers'] ?? []);
      _activeTriggers = triggers; // Store for dynamic monitoring adjustments

      if (triggers.isEmpty) return;

      final now = DateTime.now();
      final hour = now.hour;

      // 2. Check Time-based Triggers
      if (triggers.contains('Morning Rush (6-10 AM)') && hour >= 6 && hour < 10) {
        _triggerPreventativeAlert(
            "Morning Rush Detected",
            "You tend to be more rushed at this time. Take a deep breath and drive smoothly."
        );
      }
      else if (triggers.contains('Evening Traffic (4-10 PM)') && hour >= 16 && hour < 22) {
        _triggerPreventativeAlert(
            "Evening Rush Detected",
            "Traffic might be heavy. Patience is your best fuel saver right now."
        );
      }
      else if (triggers.contains('Late Night Driving') && (hour >= 22 || hour < 5)) {
        _triggerPreventativeAlert(
            "Late Night Drive",
            "Visibility is lower. Keep your speed steady and eyes scanning."
        );
      }

    } catch (e) {
      print('Failed to check stress triggers: $e');
    }
  }

  void _triggerPreventativeAlert(String title, String body) {
    if (_hasWarnedAboutTimeTrigger) return;

    // Wait a few seconds after start so user settles in
    Future.delayed(const Duration(seconds: 5), () {
      if (!_isMonitoring) return;
      sendNotification(title, body);
      _hasWarnedAboutTimeTrigger = true;
      print('⚠️ Preventative Alert Sent: $title');
    });
  }

  // ==================== DIRECTION REVERSAL DETECTION ====================

  void _detectDirectionReversal(
      double currentX,
      double currentY,
      double currentZ,
      double magnitude,
      ) {
    if (_lastDirectionX == null ||
        _lastDirectionY == null ||
        _lastDirectionZ == null) {
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

    double dotProduct =
        (_lastDirectionX! * currentX) +
            (_lastDirectionY! * currentY) +
            (_lastDirectionZ! * currentZ);

    double lastMagnitude = sqrt(
      _lastDirectionX! * _lastDirectionX! +
          _lastDirectionY! * _lastDirectionY! +
          _lastDirectionZ! * _lastDirectionZ!,
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
        print(
          "🔴 Direction Reversal Detected: ${angleDegrees.toStringAsFixed(1)}° - DECELERATION mode",
        );
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

  // TURN DETECTION METHOD
  void _detectTurn(double rawLateralForce) {
    // 1. Smooth the lateral force
    _smoothedLateralForce =
        (_kLpfAlpha * rawLateralForce) + ((1 - _kLpfAlpha) * _smoothedLateralForce);

    // 2. Speed Check: Ignore turns if moving too slowly (e.g., parking lot maneuvers)
    if (currentSpeedKmh < _kMinSpeedThresholdKmh) {
      _turnStartTime = null;
      _turnEntrySpeed = null;
      _turnPeakForce = 0.0;
      return;
    }

    // 3. Cooldown Check: Don't detect a new turn immediately after another
    if (_lastTurnDetection != null &&
        DateTime.now().difference(_lastTurnDetection!) < _kTurnCooldown) {
      return;
    }

    // 4. Turn Logic
    if (_smoothedLateralForce.abs() > _kTurnForceThreshold) {

      // --- START OF TURN ---
      if (_turnStartTime == null) {
        _turnStartTime = DateTime.now();
        _turnEntrySpeed = currentSpeedKmh;            // Capture Entry Speed
        _turnPeakForce = _smoothedLateralForce.abs(); // Initialize Peak Force
      }
      // --- DURING TURN ---
      else {
        // Continuously update peak force if current force is higher
        if (_smoothedLateralForce.abs() > _turnPeakForce) {
          _turnPeakForce = _smoothedLateralForce.abs();
        }
      }

      // Check duration
      int durationMs =
          DateTime.now().difference(_turnStartTime!).inMilliseconds;

      // --- TURN CONFIRMED ---
      if (durationMs >= _kTurnDurationMs) {
        bool gyroConfirmsRotation = true;

        // Gyroscope Validation (if enabled)
        if (_useGyroscopeFusion) {
          gyroConfirmsRotation = _smoothedGyroZ.abs() > _kGyroRotationThreshold;
          if (!gyroConfirmsRotation) {
            print("⚠️ Turn rejected: Lateral force detected but no rotation");
            _turnStartTime = null;
            _turnEntrySpeed = null;
            _turnPeakForce = 0.0;
            return;
          }
        }

        String direction = _smoothedLateralForce > 0 ? "Left" : "Right";

        // Update basic counts
        if (direction == "Left") {
          _sessionService.incrementLeftTurn();
        } else {
          _sessionService.incrementRightTurn();
        }

        // --- NEW: QUALITY ANALYSIS ---
        // Capture Exit Speed and Analyze
        double finalEntrySpeed = _turnEntrySpeed ?? currentSpeedKmh;
        double exitSpeed = currentSpeedKmh;

        _analyzeTurnQuality(finalEntrySpeed, exitSpeed, _turnPeakForce);
        
        // NEW: Real-time Feedback for Turn
        _feedbackService.evaluateTurn(_turnPeakForce, currentSpeedKmh);

        // Logging
        String gyroInfo = _useGyroscopeFusion
            ? "Gyro: ${_smoothedGyroZ.abs().toStringAsFixed(3)} rad/s"
            : "Gyro: disabled";

        print("🔄 Turn Detected: $direction turn\n"
            "   Peak Force: ${_turnPeakForce.toStringAsFixed(2)} m/s²\n"
            "   $gyroInfo\n"
            "   Duration: ${durationMs}ms\n"
            "   Speed: ${currentSpeedKmh.toStringAsFixed(0)} km/h");

        // Reset state
        _lastTurnDetection = DateTime.now();
        _turnStartTime = null;
        _turnEntrySpeed = null;
        _turnPeakForce = 0.0;
      }
    } else {
      // Force dropped below threshold -> Reset potential turn
      _turnStartTime = null;
      _turnEntrySpeed = null;
      _turnPeakForce = 0.0;
    }
  }

  // HELPER METHODS
  bool _shouldSendNotification(DateTime? lastNotification) {
    if (lastNotification == null) return true;
    return DateTime.now().difference(lastNotification) > _kNotificationCooldown;
  }

  void _checkCrashFromAcceleration(
      BuildContext context,
      WidgetRef ref,
      double avgMagnitude,
      ) {
    if (_lastCrashDetection != null &&
        DateTime.now().difference(_lastCrashDetection!) < _kCrashCooldown) {
      return;
    }

    if (_accelBuffer.length < 2) return;

    double accelFluctuation =
        _accelBuffer[_accelBuffer.length - 1].abs() -
            _accelBuffer[_accelBuffer.length - 2].abs();

    if (accelFluctuation.abs() > _kCrashAccelFluctuationLimit) {
      _triggerCrashDetection(context, ref);
    }
  }

  void _checkCrashFromSpeedDrop(BuildContext context, WidgetRef ref) {
    if (_lastCrashDetection != null &&
        DateTime.now().difference(_lastCrashDetection!) < _kCrashCooldown) {
      return;
    }

    if (_speedHistory.length < 2) return;

    final recent = _speedHistory[_speedHistory.length - 1];
    final previous = _speedHistory[_speedHistory.length - 2];

    final delTime =
        recent['time'].difference(previous['time']).inMilliseconds / 1000.0;
    final delSpeed = recent['speed'] - previous['speed'];

    if (delSpeed < _kCrashSpeedDropLimit && delTime < 1.5) {
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
    _gyroSub?.cancel();

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
          final summary = _sessionService.generateSummary(
            totalDistanceMeters / 1000,
          );
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
        final summary = _sessionService.generateSummary(
          totalDistanceMeters / 1000,
        );
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

  void _analyzeTurnQuality(double entrySpeed, double exitSpeed, double peakForce) {
    String quality = "Normal";
    String reason = "";

    // Calculate Speed Delta
    // Positive result = Speed dropped (braking)
    // Negative result = Speed increased (accelerating)
    double speedDrop = entrySpeed - exitSpeed;

    // --- SCORING LOGIC ---

    if (peakForce > _kJerkyTurnLimit) {
      quality = "Jerky";
      reason = "High G-Force (${peakForce.toStringAsFixed(1)} m/s²)";
    }
    else if (speedDrop > _kSignificantSpeedDrop) {
      quality = "Jerky";
      reason = "Hard Braking in Turn (-${speedDrop.toStringAsFixed(1)} km/h)";
    }
    // To get "Smooth", you must have low force AND consistent speed (no hard braking)
    else if (peakForce < _kSmoothTurnLimit && speedDrop < 10.0) {
      quality = "Smooth";
      reason = "Controlled & Steady";
    }

    // --- RECORDING & FEEDBACK ---

    // Record to session service (Ensure you added recordTurnQuality to SessionSummaryService)
    _sessionService.recordTurnQuality(quality);

    print("🏁 Turn Quality: $quality | $reason | Entry: ${entrySpeed.toStringAsFixed(1)} -> Exit: ${exitSpeed.toStringAsFixed(1)}");

    // Optional: Trigger a notification for bad turns if not in cooldown
    if (quality == "Jerky") {
      // Re-using your existing notification cooldown logic
      if (_shouldSendNotification(_lastHarshAccelNotification)) { // piggybacking on harsh accel timer or create a new one
        sendNotification(
            "Rough Corner Detected",
            "Try braking before the turn, not during it."
        );

        // COACHING: Voice + Haptic Feedback for Turns
        // Pattern: [0, 100, 50, 100, 50, 100] -> Rapid pulses
        _coachingService.triggerFeedback(
            message: "Watch your cornering.",
            vibrationPattern: [0, 100, 50, 100, 50, 100]
        );
      }
    }
  }
}