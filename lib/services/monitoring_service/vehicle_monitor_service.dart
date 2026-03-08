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
import '../../providers/sensor_thresholds_provider.dart';
import '../notifications_services.dart';
import 'package:raxxy/services/monitoring_service/feedback_service.dart';

class VehicleMonitorService {
  // ==============================================================================
  // 🔧 RUNTIME THRESHOLDS
  // Loaded from SensorThresholdsProvider when startMonitoring() is called.
  // Defaults match the original hardcoded constants exactly.
  // ==============================================================================
  late SensorThresholds _t;

  // Fixed internal constant — LPF smoothing, not user-configurable
  static const double _kLpfAlpha = 0.15;

  // Minimum GPS speed (km/h) below which direction-reversal logic is skipped.
  // Prevents gravity-vector shifts at standstill from being misread as braking.
  static const double _kMinSpeedForReversalKmh = 3.0;

  // Number of consecutive samples the reversal angle must persist before we
  // commit to _isDecelerating = true.  Prevents single-spike false positives.
  static const int _kReversalHysteresisCount = 3;

  // ==================== ACCIDENT RISK ====================
  double _currentRiskScore = 0;
  String _currentRiskLevel = 'Low';
  DateTime? _lastRiskAlert;
  static const Duration _kRiskCooldown = Duration(seconds: 8);

  // ==============================================================================

  final ValueNotifier<String?> monitoredVehicleIdNotifier = ValueNotifier(null);
  final ValueNotifier<double>  currentSpeedNotifier        = ValueNotifier(0.0);
  final ValueNotifier<double>  currentAccelerationNotifier = ValueNotifier(0.0);
  final ValueNotifier<double>  currentDistanceNotifier     = ValueNotifier(0.0);

  static final VehicleMonitorService _instance = VehicleMonitorService._internal();
  factory VehicleMonitorService() => _instance;
  VehicleMonitorService._internal() {
    _t = const SensorThresholds();
  }

  // Service instances
  final SessionSummaryService _sessionService  = SessionSummaryService();
  final CoachingService       _coachingService = CoachingService();
  final FeedbackService       _feedbackService = FeedbackService();

  StreamSubscription<UserAccelerometerEvent>? _accelSub;
  StreamSubscription<Position>?               _positionSub;
  StreamSubscription<GyroscopeEvent>?         _gyroSub;
  Timer? _uiUpdateTimer;
  Timer? _speedZoneTimer;

  UserAccelerometerEvent? currentAcceleration;
  double currentSpeedKmh = 0.0;

  final List<Map<String, dynamic>> _speedHistory = [];

  double    totalDistanceMeters = 0.0;
  Position? _lastPosition;
  bool      _isMonitoring = false;

  final List<double> _accelBuffer  = [];
  final int          _acBufferSize = 5;
  final int          sustainedSampleCount = 1;

  String? _userId;
  String? _vehicleId;

  DateTime? _lastHarshAccelNotification;
  DateTime? _lastHarshBrakeNotification;
  DateTime? _lastCrashDetection;

  int _consecutiveHarshAccel = 0;
  int _consecutiveHarshBrake = 0;

  BuildContext? _monitoringContext;

  // ==================== TRIGGER TRACKING ====================
  bool         _hasWarnedAboutTimeTrigger = false;
  List<String> _activeTriggers            = [];
  int          _lowSpeedCounter           = 0;

  // ==================== TURN DETECTION ====================
  double    _smoothedLateralForce = 0.0;
  DateTime? _turnStartTime;
  DateTime? _lastTurnDetection;
  double?   _turnEntrySpeed;
  double    _turnPeakForce = 0.0;

  // ==================== GYROSCOPE ====================
  double     _smoothedGyroZ      = 0.0;
  final bool _useGyroscopeFusion = true;

  // ==================== DIRECTION DETECTION ====================
  double? _lastDirectionX;
  double? _lastDirectionY;
  double? _lastDirectionZ;
  bool    _isDecelerating = false;

  // Hysteresis counter — counts consecutive samples above the reversal threshold
  // before committing to deceleration mode.
  int _reversalConfirmCount = 0;

  final double magnitudeSettledThreshold  = 0.5;
  final double directionReversalThreshold = 160.0;

  // ==============================================================================
  // START MONITORING
  // ==============================================================================
  Future<void> startMonitoring({
    required BuildContext context,
    required String       userId,
    required String       vehicleId,
    required String       make,
    required String       model,
    required WidgetRef    ref,
  }) async {
    // Snapshot user-configured thresholds at session start
    _t = ref.read(sensorThresholdsProvider);

    // Reset turn detection
    _smoothedLateralForce = 0.0;
    _turnStartTime        = null;
    _lastTurnDetection    = null;

    // Reset trigger tracking
    _hasWarnedAboutTimeTrigger = false;
    _activeTriggers            = [];
    _lowSpeedCounter           = 0;

    if (_isMonitoring) return;
    _isMonitoring      = true;
    _userId            = userId;
    _vehicleId         = vehicleId;
    _monitoringContext = context;

    _sessionService.startSession();
    _lastCrashDetection    = null;
    _consecutiveHarshAccel = 0;
    _consecutiveHarshBrake = 0;
    _lastTurnDetection     = null;
    _lastDirectionX        = null;
    _lastDirectionY        = null;
    _lastDirectionZ        = null;
    _isDecelerating        = false;
    _reversalConfirmCount  = 0;

    ref.read(vehicleMonitorProvider.notifier).setVehicle(vehicleId);
    ref.read(vehicleMonitorProvider.notifier).setMake(make);
    ref.read(vehicleMonitorProvider.notifier).setModel(model);
    final crashFeature = ref.watch(featureNotifierProvider);

    // ✅ Only start/stop notifications are kept
    sendNotification('RAXXY', 'Monitoring service started');
    debugPrint('RAXXY: Monitoring service started');
    debugPrint(
      '🔧 Thresholds — accel: ${_t.accelerationThreshold} m/s², '
          'turnForce: ${_t.turnForceThreshold} m/s², '
          'crashDrop: ${_t.crashSpeedDropLimit} km/h',
    );

    _checkStressTriggers(userId);

    try {
      await WakelockPlus.enable();
      debugPrint('Wakelock enabled');
    } catch (e) {
      debugPrint('Failed to enable wakelock: $e');
    }

    await _feedbackService.initialize(userId);
    _feedbackService.evaluateWeather(ref);

    // UI update timer (500 ms)
    _uiUpdateTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (_accelBuffer.isNotEmpty) {
        final avgAccel = _accelBuffer.reduce((a, b) => a + b) / _accelBuffer.length;
        ref.read(vehicleMonitorProvider.notifier).updateAcceleration(avgAccel);
      }
      ref.read(vehicleMonitorProvider.notifier).updateSpeed(currentSpeedKmh);
      ref.read(vehicleMonitorProvider.notifier).updateDistance(totalDistanceMeters);
      _sessionService.updateSpeed(currentSpeedKmh);

      if (_activeTriggers.contains('Heavy Traffic')) {
        if (currentSpeedKmh < 30 && currentSpeedKmh > 0) {
          _lowSpeedCounter++;
          if (_lowSpeedCounter > 600) {
            _triggerPreventativeAlert(
              'Traffic Detected',
              "We know heavy traffic stresses you out. Stay cool!",
            );
            _lowSpeedCounter = -600;
          }
        } else {
          _lowSpeedCounter = 0;
        }
      }
    });

    // ==================== ACCELEROMETER ====================
    _accelSub = userAccelerometerEvents.listen((event) {
      currentAcceleration = event;
      _detectTurn(event.x);

      final magnitude = sqrt(
        event.x * event.x + event.y * event.y + event.z * event.z,
      );

      // ✅ FIX: only run direction reversal when moving — avoids gravity-vector
      //         shifts at standstill causing false deceleration reads.
      if (currentSpeedKmh > _kMinSpeedForReversalKmh) {
        _detectDirectionReversal(event.x, event.y, event.z, magnitude);
      } else {
        // Parked / near-stationary — always treat as forward/neutral
        _isDecelerating       = false;
        _reversalConfirmCount = 0;
        _lastDirectionX       = event.x;
        _lastDirectionY       = event.y;
        _lastDirectionZ       = event.z;
      }

      final signedAcceleration = _isDecelerating ? -magnitude : magnitude;

      _accelBuffer.add(signedAcceleration);
      if (_accelBuffer.length > _acBufferSize) _accelBuffer.removeAt(0);

      if (_accelBuffer.length == _acBufferSize &&
          currentSpeedKmh > _t.minSpeedThresholdKmh) {
        final avgAccel     = _accelBuffer.reduce((a, b) => a + b) / _accelBuffer.length;
        final avgMagnitude = avgAccel.abs();

        // Jitter / noise filter
        double variance = 0;
        for (final val in _accelBuffer) {
          variance += pow(val.abs() - avgMagnitude, 2);
        }
        final stdDev = sqrt(variance / _accelBuffer.length);

        if (stdDev > _t.jitterThreshold) {
          _consecutiveHarshAccel = 0;
          _consecutiveHarshBrake = 0;
          return;
        }

        if (avgMagnitude > _t.accelerationThreshold) {
          if (avgAccel > 0) {
            // ---- HARSH ACCELERATION ----
            _consecutiveHarshAccel++;
            _consecutiveHarshBrake = 0;
            _sessionService.updateAccelDecelState('accel');

            if (_consecutiveHarshAccel >= sustainedSampleCount &&
                _shouldSendHaptic(_lastHarshAccelNotification)) {
              _sessionService.incrementHarshAccel();
              _lastHarshAccelNotification = DateTime.now();

              // ✅ Haptic fired directly — guaranteed, no FeedbackService gate
              _coachingService.triggerFeedback(
                message: 'Easy on the gas!',
                vibrationPattern: [0, 200, 100, 200],
              );

              // FeedbackService handles voice + personalized coaching
              _feedbackService.evaluateAcceleration(avgMagnitude, currentSpeedKmh);

              debugPrint('🟢 Harsh ACCELERATION: ${avgMagnitude.toStringAsFixed(2)} m/s²');
              _consecutiveHarshAccel = 0;
            }
          } else {
            // ---- HARSH BRAKING ----
            _consecutiveHarshBrake++;
            _consecutiveHarshAccel = 0;
            _sessionService.updateAccelDecelState('decel');

            if (_consecutiveHarshBrake >= sustainedSampleCount &&
                _shouldSendHaptic(_lastHarshBrakeNotification)) {
              _sessionService.incrementHarshBrake();
              _lastHarshBrakeNotification = DateTime.now();

              // ✅ Haptic fired directly — guaranteed, no FeedbackService gate
              _coachingService.triggerFeedback(
                message: 'Easy on the brakes!',
                vibrationPattern: [0, 500, 100, 300],
              );

              // FeedbackService handles voice + personalized coaching
              _feedbackService.evaluateBraking(avgMagnitude, currentSpeedKmh);

              debugPrint('🔴 Harsh BRAKING: ${avgMagnitude.toStringAsFixed(2)} m/s²');
              _consecutiveHarshBrake = 0;
            }
          }
        } else {
          _consecutiveHarshAccel = 0;
          _consecutiveHarshBrake = 0;
          _sessionService.updateAccelDecelState('neutral');
        }

        if (crashFeature == true) {
          _checkCrashFromAcceleration(context, ref, avgMagnitude);
        }
      } else if (currentSpeedKmh <= _t.minSpeedThresholdKmh) {
        _consecutiveHarshAccel = 0;
        _consecutiveHarshBrake = 0;
      }
    });

    // Location permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        debugPrint('Location permission not granted');
        return;
      }
    }

    // ==================== GYROSCOPE ====================
    if (_useGyroscopeFusion) {
      _gyroSub = gyroscopeEvents.listen((GyroscopeEvent event) {
        _smoothedGyroZ = (_kLpfAlpha * event.z) + ((1 - _kLpfAlpha) * _smoothedGyroZ);
      });
      debugPrint('✅ Gyroscope fusion enabled');
    }

    // ==================== GPS ====================
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 1,
      ),
    ).listen((position) {
      final now = DateTime.now();
      currentSpeedKmh = position.speed * 3.6;

      _speedHistory.add({'time': now, 'speed': currentSpeedKmh});
      if (_speedHistory.length > 10) _speedHistory.removeAt(0);

      if (crashFeature == true && _speedHistory.length >= 2) {
        _checkCrashFromSpeedDrop(context, ref);
      }

      if (_lastPosition != null) {
        totalDistanceMeters += Geolocator.distanceBetween(
          _lastPosition!.latitude,
          _lastPosition!.longitude,
          position.latitude,
          position.longitude,
        );
      }
      _lastPosition = position;
    });

    _calculateAccidentRisk(ref);
    debugPrint('✅ Monitoring started');
  }

  // ==================== STRESS TRIGGERS ====================

  Future<void> _checkStressTriggers(String userId) async {
    try {
      final profile = await DriverProfileService.getCachedProfile(userId);
      if (profile == null) return;

      final triggers = List<String>.from(profile['stressTriggers'] ?? []);
      _activeTriggers = triggers;
      if (triggers.isEmpty) return;

      final hour = DateTime.now().hour;
      if (triggers.contains('Morning Rush (6-10 AM)') && hour >= 6 && hour < 10) {
        _triggerPreventativeAlert('Morning Rush Detected',
            'You tend to be more rushed at this time. Take a deep breath and drive smoothly.');
      } else if (triggers.contains('Evening Traffic (4-10 PM)') && hour >= 16 && hour < 22) {
        _triggerPreventativeAlert('Evening Rush Detected',
            'Traffic might be heavy. Patience is your best fuel saver right now.');
      } else if (triggers.contains('Late Night Driving') && (hour >= 22 || hour < 5)) {
        _triggerPreventativeAlert('Late Night Drive',
            'Visibility is lower. Keep your speed steady and eyes scanning.');
      }
    } catch (e) {
      debugPrint('Failed to check stress triggers: $e');
    }
  }

  void _triggerPreventativeAlert(String title, String body) {
    if (_hasWarnedAboutTimeTrigger) return;
    Future.delayed(const Duration(seconds: 5), () {
      if (!_isMonitoring) return;
      // ✅ No push notification — stress alerts are voice/haptic only
      _coachingService.triggerFeedback(
        message: body,
        vibrationPattern: [0, 200],
      );
      _hasWarnedAboutTimeTrigger = true;
      debugPrint('⚠️ Preventative Alert (haptic+voice): $title');
    });
  }

  // ==================== DIRECTION REVERSAL ====================
  //
  // FIX SUMMARY:
  //   Problem: When stationary the accelerometer reads ~9.8 m/s² of gravity on
  //            the Z-axis.  Starting to accelerate shifts force to Y-axis, making
  //            the angle between the old (gravity) and new (gravity+accel) vectors
  //            exceed 160° — falsely flagging deceleration.
  //
  //   Solution 1 — Speed gate (caller level):
  //     _detectDirectionReversal is only called when currentSpeedKmh > 3.0.
  //     Below that speed the state is held at neutral.
  //
  //   Solution 2 — Hysteresis counter (here):
  //     The reversal angle must be observed for _kReversalHysteresisCount
  //     consecutive samples before _isDecelerating flips to true.
  //     A single-sample spike (sensor noise, pot-hole, etc.) is ignored.

  void _detectDirectionReversal(
      double currentX,
      double currentY,
      double currentZ,
      double magnitude,
      ) {
    if (_lastDirectionX == null || _lastDirectionY == null || _lastDirectionZ == null) {
      _lastDirectionX       = currentX;
      _lastDirectionY       = currentY;
      _lastDirectionZ       = currentZ;
      _reversalConfirmCount = 0;
      return;
    }

    // If magnitude is tiny, sensor is settled / near-zero motion — reset to neutral
    if (magnitude < magnitudeSettledThreshold) {
      _isDecelerating       = false;
      _reversalConfirmCount = 0;
      _lastDirectionX       = currentX;
      _lastDirectionY       = currentY;
      _lastDirectionZ       = currentZ;
      return;
    }

    final dotProduct =
        (_lastDirectionX! * currentX) +
            (_lastDirectionY! * currentY) +
            (_lastDirectionZ! * currentZ);

    final lastMagnitude = sqrt(
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

    final cosTheta     = (dotProduct / (lastMagnitude * magnitude)).clamp(-1.0, 1.0);
    final angleDegrees = acos(cosTheta) * (180 / pi);

    if (angleDegrees > directionReversalThreshold) {
      // ✅ FIX: require N consecutive reversals before committing
      _reversalConfirmCount++;
      if (_reversalConfirmCount >= _kReversalHysteresisCount && !_isDecelerating) {
        _isDecelerating = true;
        debugPrint('🔴 Direction Reversal confirmed after $_reversalConfirmCount samples — DECELERATION mode');
      }
    } else {
      // Angle is within normal range — reset hysteresis and potentially exit decel mode
      _reversalConfirmCount = 0;
      if (magnitude < magnitudeSettledThreshold && _isDecelerating) {
        _isDecelerating = false;
        debugPrint('🟢 Settled — ACCELERATION mode');
      }
    }

    _lastDirectionX = currentX;
    _lastDirectionY = currentY;
    _lastDirectionZ = currentZ;
  }

  // ==================== TURN DETECTION ====================

  void _detectTurn(double rawLateralForce) {
    _smoothedLateralForce =
        (_kLpfAlpha * rawLateralForce) + ((1 - _kLpfAlpha) * _smoothedLateralForce);

    if (currentSpeedKmh < _t.minSpeedThresholdKmh) {
      _resetTurnState();
      return;
    }

    if (_lastTurnDetection != null &&
        DateTime.now().difference(_lastTurnDetection!) <
            Duration(seconds: _t.turnCooldownSeconds)) {
      return;
    }

    if (_smoothedLateralForce.abs() > _t.turnForceThreshold) {
      if (_turnStartTime == null) {
        _turnStartTime  = DateTime.now();
        _turnEntrySpeed = currentSpeedKmh;
        _turnPeakForce  = _smoothedLateralForce.abs();
      } else if (_smoothedLateralForce.abs() > _turnPeakForce) {
        _turnPeakForce = _smoothedLateralForce.abs();
      }

      final durationMs = DateTime.now().difference(_turnStartTime!).inMilliseconds;

      if (durationMs >= _t.turnDurationMs) {
        if (_useGyroscopeFusion) {
          if (_smoothedGyroZ.abs() <= _t.gyroRotationThreshold) {
            debugPrint('⚠️ Turn rejected: no gyro rotation');
            _resetTurnState();
            return;
          }
        }

        final direction = _smoothedLateralForce > 0 ? 'Left' : 'Right';
        if (direction == 'Left') {
          _sessionService.incrementLeftTurn();
        } else {
          _sessionService.incrementRightTurn();
        }

        _analyzeTurnQuality(
            _turnEntrySpeed ?? currentSpeedKmh, currentSpeedKmh, _turnPeakForce);
        _feedbackService.evaluateTurn(_turnPeakForce, currentSpeedKmh);

        debugPrint(
          '🔄 Turn: $direction | Peak: ${_turnPeakForce.toStringAsFixed(2)} m/s² | '
              '${durationMs}ms | ${currentSpeedKmh.toStringAsFixed(0)} km/h',
        );

        _lastTurnDetection = DateTime.now();
        _resetTurnState();
      }
    } else {
      _resetTurnState();
    }
  }

  void _resetTurnState() {
    _turnStartTime  = null;
    _turnEntrySpeed = null;
    _turnPeakForce  = 0.0;
  }

  // ==================== HAPTIC COOLDOWN ====================
  // Separate from the notification cooldown — controls how often direct
  // haptic triggers fire.  Uses the same timestamps as notifications.

  bool _shouldSendHaptic(DateTime? lastTime) {
    if (lastTime == null) return true;
    return DateTime.now().difference(lastTime) >
        Duration(seconds: _t.notificationCooldownSeconds);
  }

  // ==================== CRASH DETECTION ====================

  void _checkCrashFromAcceleration(
      BuildContext context,
      WidgetRef ref,
      double avgMagnitude,
      ) {
    if (_lastCrashDetection != null &&
        DateTime.now().difference(_lastCrashDetection!) <
            Duration(seconds: _t.crashCooldownSeconds)) return;
    if (_accelBuffer.length < 2) return;

    final accelFluctuation =
        _accelBuffer[_accelBuffer.length - 1].abs() -
            _accelBuffer[_accelBuffer.length - 2].abs();

    if (accelFluctuation.abs() > _t.crashAccelFluctuationLimit) {
      _triggerCrashDetection(context, ref);
    }
  }

  void _checkCrashFromSpeedDrop(BuildContext context, WidgetRef ref) {
    if (_lastCrashDetection != null &&
        DateTime.now().difference(_lastCrashDetection!) <
            Duration(seconds: _t.crashCooldownSeconds)) return;
    if (_speedHistory.length < 2) return;

    final recent   = _speedHistory[_speedHistory.length - 1];
    final previous = _speedHistory[_speedHistory.length - 2];

    final delTime  = recent['time'].difference(previous['time']).inMilliseconds / 1000.0;
    final delSpeed = (recent['speed'] as double) - (previous['speed'] as double);

    if (delSpeed < -_t.crashSpeedDropLimit && delTime < 1.5) {
      _triggerCrashDetection(context, ref);
    }
  }

  void _triggerCrashDetection(BuildContext context, WidgetRef ref) {
    _lastCrashDetection = DateTime.now();
    debugPrint('CRASH DETECTED — triggering crash protocol');

    // ✅ Crash notification kept — it's part of the safety-critical emergency flow
    sendNotification('Crash Detected', 'Possible impact detected');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        CrashDetector.checkForCrash(context, ref, onDialogClosed: () {
          debugPrint('Crash dialog closed');
        });
      }
    });
  }

  // ==================== STOP MONITORING ====================

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
      debugPrint('Wakelock disabled');
    } catch (e) {
      debugPrint('Failed to disable wakelock: $e');
    }

    if (_userId != null && _vehicleId != null) {
      try {
        final firestore  = FirebaseFirestore.instance;
        final vehicleDoc = firestore
            .collection('users')
            .doc(_userId)
            .collection('vehicles')
            .doc(_vehicleId);

        final mileageToAdd = manualMileage ?? (totalDistanceMeters / 1000);

        await firestore.runTransaction((transaction) async {
          final snapshot = await transaction.get(vehicleDoc);
          if (snapshot.exists) {
            final currentMileage = snapshot.data()?['mileage'] ?? 0;
            transaction.update(vehicleDoc, {
              'mileage': currentMileage + mileageToAdd.round(),
            });
          }
        });

        _showSnack('✅ Mileage updated: +${mileageToAdd.toStringAsFixed(2)} km', Colors.green);
        await Future.delayed(const Duration(milliseconds: 500));

        await _sessionService.saveSummary(
          userId: _userId!,
          vehicleId: _vehicleId!,
          totalDistanceKm: totalDistanceMeters / 1000,
        );

        final summary = _sessionService.generateSummary(totalDistanceMeters / 1000);
        _showSnack(
          '💾 Trip saved (${summary['durationMinutes']} min, '
              '${(totalDistanceMeters / 1000).toStringAsFixed(1)} km)',
          Colors.blue,
        );
        await Future.delayed(const Duration(milliseconds: 500));

        await DrivingScoreService.updateDrivingScore(
          userId: _userId!,
          harshAccelEvents: _sessionService.harshAccelEvents,
          harshBrakeEvents: _sessionService.harshBrakeEvents,
          sessionDurationMinutes: summary['durationMinutes'],
        );

        _showSnack(
          '📊 Score updated (${_sessionService.harshAccelEvents} accel, '
              '${_sessionService.harshBrakeEvents} brakes)',
          Colors.orange,
        );
        await Future.delayed(const Duration(milliseconds: 500));

        await GoalsGenerationService.generateGoals(
          userId: _userId!,
          vehicleId: _vehicleId!,
          harshAccelEvents: _sessionService.harshAccelEvents,
          harshBrakeEvents: _sessionService.harshBrakeEvents,
          sessionDurationMinutes: summary['durationMinutes'],
        );

        _showSnack('🎯 Goals updated based on your performance', Colors.purple);
      } catch (e) {
        debugPrint('Failed to update vehicle data: $e');
        _showSnack('❌ Error: ${e.toString()}', Colors.red);
      }
    }

    // ✅ Only stop notification kept
    sendNotification('RAXXY', 'Monitoring service stopped');

    ref.read(vehicleMonitorProvider.notifier).clear();
    _monitoringContext = null;
    debugPrint('Monitoring stopped');
  }

  void _showSnack(String message, Color color) {
    if (_monitoringContext != null && _monitoringContext!.mounted) {
      ScaffoldMessenger.of(_monitoringContext!).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // ==================== TURN QUALITY ====================

  void _analyzeTurnQuality(double entrySpeed, double exitSpeed, double peakForce) {
    String quality = 'Normal';
    String reason  = '';
    final speedDrop = entrySpeed - exitSpeed;

    if (peakForce > _t.jerkyTurnLimit) {
      quality = 'Jerky';
      reason  = 'High G-Force (${peakForce.toStringAsFixed(1)} m/s²)';
    } else if (speedDrop > _t.significantSpeedDrop) {
      quality = 'Jerky';
      reason  = 'Hard Braking in Turn (-${speedDrop.toStringAsFixed(1)} km/h)';
    } else if (peakForce < _t.smoothTurnLimit && speedDrop < 10.0) {
      quality = 'Smooth';
      reason  = 'Controlled & Steady';
    }

    _sessionService.recordTurnQuality(quality);
    debugPrint(
      '🏁 Turn Quality: $quality | $reason | '
          'Entry: ${entrySpeed.toStringAsFixed(1)} → Exit: ${exitSpeed.toStringAsFixed(1)}',
    );

    // ✅ Jerky turn: haptic fired directly, no push notification
    if (quality == 'Jerky' && _shouldSendHaptic(_lastHarshAccelNotification)) {
      _coachingService.triggerFeedback(
        message: 'Watch your cornering.',
        vibrationPattern: [0, 100, 50, 100, 50, 100],
      );
    }
  }

  // ==================== ACCIDENT RISK ====================

  void _calculateAccidentRisk(WidgetRef ref) {
    double risk = 0;
    if (currentSpeedKmh > 80)                 risk += 25;
    if (_sessionService.harshAccelEvents > 2)  risk += 20;
    if (_sessionService.harshBrakeEvents > 2)  risk += 20;
    final hour = DateTime.now().hour;
    if (hour >= 22 || hour < 5)               risk += 10;
    if (_turnPeakForce > 4.5)                 risk += 15;

    _currentRiskScore = risk;
    _currentRiskLevel = risk <= 30 ? 'Low' : risk <= 60 ? 'Medium' : 'High';

    ref.read(vehicleMonitorProvider.notifier).updateRisk(_currentRiskScore, _currentRiskLevel);

    if (_lastRiskAlert == null ||
        DateTime.now().difference(_lastRiskAlert!) > _kRiskCooldown) {
      _feedbackService.evaluateAccidentRisk(_currentRiskLevel, _currentRiskScore);
      _lastRiskAlert = DateTime.now();
    }
  }
}