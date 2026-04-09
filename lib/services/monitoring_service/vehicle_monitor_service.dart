import 'dart:async';
import 'dart:math';
import 'dart:collection';
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
import '../../widgets/reusable_widgets.dart';
import '../racing_telemetary_core.dart';

// Helper classes for sliding windows
class TimeStampedValue {
  final DateTime time;
  final double value;
  TimeStampedValue(this.time, this.value);
}

class VehicleMonitorService {
  // ==============================================================================
  // 🔧 RUNTIME THRESHOLDS
  // ==============================================================================
  late SensorThresholds _t;

  static const double _kLpfAlpha = 0.15;
  static const double _kMinSpeedForReversalKmh = 3.0;
  static const int _kReversalHysteresisCount = 3;

  // ==================== STATE ====================
  bool _isTrackMode = false;
  final RacingTelemetryService _telemetryService = RacingTelemetryService();

  // ==================== ACCIDENT RISK ====================
  double _currentRiskScore = 0;
  String _currentRiskLevel = 'Low';
  DateTime? _lastRiskAlert;
  static const Duration _kRiskCooldown = Duration(seconds: 8);

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
  StreamSubscription<MagnetometerEvent>?      _magSub;
  StreamSubscription<Position>?               _positionSub;
  StreamSubscription<GyroscopeEvent>?         _gyroSub;
  Timer? _uiUpdateTimer;
  Timer? _speedZoneTimer;

  UserAccelerometerEvent? currentAcceleration;
  MagnetometerEvent?      currentMagnetometer;
  double currentSpeedKmh = 0.0;

  final List<Map<String, dynamic>> _speedHistory = [];

  double    totalDistanceMeters = 0.0;
  Position? _lastPosition;
  bool      _isMonitoring = false;

  // ==================== JERK STANDARD DEVIATION ====================
  final Queue<TimeStampedValue> _jerkBuffer = Queue();
  double?   _lastMagnitude;
  DateTime? _lastAccelTimestamp;

  final List<double> _rawAccelMagnitudes = [];
  final int sustainedSampleCount = 1;

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
  final Queue<TimeStampedValue> _yawRateBuffer = Queue();
  double?   _lastYaw;
  DateTime? _lastYawTimestamp;
  DateTime? _turnStartTime;
  DateTime? _lastTurnDetection;
  double?   _turnEntrySpeed;
  double    _turnPeakYawRate = 0.0;

  // ==================== GYROSCOPE ====================
  double     _smoothedGyroZ      = 0.0;
  final bool _useGyroscopeFusion = true;

  // ==================== DIRECTION DETECTION ====================
  double? _lastDirectionX;
  double? _lastDirectionY;
  double? _lastDirectionZ;
  bool    _isDecelerating = false;

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
    bool                  trackMode = false, // Inject Track Mode flag
  }) async {
    _t = ref.read(sensorThresholdsProvider);
    _isTrackMode = trackMode;

    _turnStartTime        = null;
    _lastTurnDetection    = null;
    _turnPeakYawRate      = 0.0;

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

    _jerkBuffer.clear();
    _yawRateBuffer.clear();
    _lastMagnitude = null;
    _lastAccelTimestamp = null;
    _lastYaw = null;
    _lastYawTimestamp = null;
    _rawAccelMagnitudes.clear();

    ref.read(vehicleMonitorProvider.notifier).setVehicle(vehicleId);
    ref.read(vehicleMonitorProvider.notifier).setMake(make);
    ref.read(vehicleMonitorProvider.notifier).setModel(model);
    final crashFeature = ref.watch(featureNotifierProvider);

    sendNotification('RAXXY', _isTrackMode ? 'Track Mode Active' : 'Monitoring service started');
    debugPrint('RAXXY: Monitoring service started. Track Mode: $_isTrackMode');

    _checkStressTriggers(userId);

    try {
      await WakelockPlus.enable();
      debugPrint('Wakelock enabled');
    } catch (e) {
      debugPrint('Failed to enable wakelock: $e');
    }

    if (!_isTrackMode) {
      await _feedbackService.initialize(userId);
      _feedbackService.evaluateWeather(ref);
    }

    // ==================== UI UPDATE TIMER ====================
    _uiUpdateTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      // Common updates for both modes
      ref.read(vehicleMonitorProvider.notifier).updateSpeed(currentSpeedKmh);
      ref.read(vehicleMonitorProvider.notifier).updateDistance(totalDistanceMeters);
      _sessionService.updateSpeed(currentSpeedKmh);

      if (!_isTrackMode) {
        // CITY NANNY LOGIC
        if (_jerkBuffer.isNotEmpty) {
          final avgJerk = _jerkBuffer.map((e) => e.value).reduce((a, b) => a + b) / _jerkBuffer.length;
          ref.read(vehicleMonitorProvider.notifier).updateAcceleration(avgJerk);
        }

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
      } else {
        // TRACK MODE TELEMETRY ROUTING
        if (currentAcceleration != null) {
          _telemetryService.processTrackTelemetry(
            currentSpeed: currentSpeedKmh,
            accelX: currentAcceleration!.x,
            accelY: currentAcceleration!.y,
            gyroZ: _useGyroscopeFusion ? _smoothedGyroZ : 0.0,
          );
        }
      }
    });

    // ==================== MAGNETOMETER ====================
    _magSub = magnetometerEvents.listen((event) {
      currentMagnetometer = event;
    });

    // ==================== ACCELEROMETER ====================
    _accelSub = userAccelerometerEvents.listen((event) {
      final now = DateTime.now();
      currentAcceleration = event;

      final magnitude = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);

      if (currentSpeedKmh > _kMinSpeedForReversalKmh) {
        _detectDirectionReversal(event.x, event.y, event.z, magnitude);
      } else {
        _isDecelerating       = false;
        _reversalConfirmCount = 0;
        _lastDirectionX       = event.x;
        _lastDirectionY       = event.y;
        _lastDirectionZ       = event.z;
      }

      final signedAcceleration = _isDecelerating ? -magnitude : magnitude;

      _rawAccelMagnitudes.add(signedAcceleration);
      if (_rawAccelMagnitudes.length > 5) _rawAccelMagnitudes.removeAt(0);

      // Jerk calculation
      if (_lastMagnitude != null && _lastAccelTimestamp != null) {
        final dt = now.difference(_lastAccelTimestamp!).inMicroseconds / 1e6;
        if (dt > 0) {
          final jerk = (signedAcceleration - _lastMagnitude!) / dt;
          _jerkBuffer.add(TimeStampedValue(now, jerk));
        }
      }
      _lastMagnitude = signedAcceleration;
      _lastAccelTimestamp = now;

      while (_jerkBuffer.isNotEmpty && now.difference(_jerkBuffer.first.time).inSeconds >= 1) {
        _jerkBuffer.removeFirst();
      }

      if (currentMagnetometer != null) {
        _calculateAndProcessYaw(event, currentMagnetometer!, now);
      }

      // Bifurcate Nanny Jerk Logic
      if (!_isTrackMode) {
        if (_jerkBuffer.length >= 10 && currentSpeedKmh > _t.minSpeedThresholdKmh) {
          double meanJerk = _jerkBuffer.map((e) => e.value).reduce((a, b) => a + b) / _jerkBuffer.length;
          double variance = _jerkBuffer.map((e) => pow(e.value - meanJerk, 2)).reduce((a, b) => a + b) / _jerkBuffer.length;
          double jerkStdDev = sqrt(variance);

          final double jerkThreshold = _t.jerkStdDevThreshold;

          if (jerkStdDev > jerkThreshold) {
            if (!_isDecelerating) {
              _consecutiveHarshAccel++;
              _consecutiveHarshBrake = 0;
              _sessionService.updateAccelDecelState('accel');

              if (_consecutiveHarshAccel >= sustainedSampleCount && _shouldSendHaptic(_lastHarshAccelNotification)) {
                _sessionService.incrementHarshAccel();
                _lastHarshAccelNotification = DateTime.now();

                _coachingService.triggerFeedback(
                  message: 'Easy on the gas!',
                  vibrationPattern: [0, 200, 100, 200],
                );
                _feedbackService.evaluateAcceleration(jerkStdDev, currentSpeedKmh);
                debugPrint('🟢 Harsh ACCELERATION (Jerk StdDev): ${jerkStdDev.toStringAsFixed(2)} m/s³');
                _consecutiveHarshAccel = 0;
              }
            } else {
              _consecutiveHarshBrake++;
              _consecutiveHarshAccel = 0;
              _sessionService.updateAccelDecelState('decel');

              if (_consecutiveHarshBrake >= sustainedSampleCount && _shouldSendHaptic(_lastHarshBrakeNotification)) {
                _sessionService.incrementHarshBrake();
                _lastHarshBrakeNotification = DateTime.now();

                _coachingService.triggerFeedback(
                  message: 'Easy on the brakes!',
                  vibrationPattern: [0, 500, 100, 300],
                );
                _feedbackService.evaluateBraking(jerkStdDev, currentSpeedKmh);
                debugPrint('🔴 Harsh BRAKING (Jerk StdDev): ${jerkStdDev.toStringAsFixed(2)} m/s³');
                _consecutiveHarshBrake = 0;
              }
            }
          } else {
            _consecutiveHarshAccel = 0;
            _consecutiveHarshBrake = 0;
            _sessionService.updateAccelDecelState('neutral');
          }

          if (crashFeature == true) {
            _checkCrashFromAcceleration(context, ref, jerkStdDev);
          }
        } else if (currentSpeedKmh <= _t.minSpeedThresholdKmh) {
          _consecutiveHarshAccel = 0;
          _consecutiveHarshBrake = 0;
        }
      }
    });

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.always && permission != LocationPermission.whileInUse) {
        debugPrint('Location permission not granted');
        return;
      }
    }

    if (_useGyroscopeFusion) {
      _gyroSub = gyroscopeEvents.listen((GyroscopeEvent event) {
        _smoothedGyroZ = (_kLpfAlpha * event.z) + ((1 - _kLpfAlpha) * _smoothedGyroZ);
      });
    }

    // ==================== GPS STREAM ====================
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 1,
      ),
    ).listen((position) {
      final now = DateTime.now();
      currentSpeedKmh = position.speed * 3.6;

      if (!_isTrackMode) {
        _speedHistory.add({'time': now, 'speed': currentSpeedKmh});
        if (_speedHistory.length > 10) _speedHistory.removeAt(0);

        if (crashFeature == true && _speedHistory.length >= 2) {
          _checkCrashFromSpeedDrop(context, ref);
        }
      } else {
        // Route raw coordinates to the telemetry engine
        _telemetryService.updateGpsPosition(position.latitude, position.longitude);
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

  // ==================== YAW CALCULATION ====================
  void _calculateAndProcessYaw(UserAccelerometerEvent accel, MagnetometerEvent mag, DateTime now) {
    double normA = sqrt(accel.x * accel.x + accel.y * accel.y + accel.z * accel.z);
    if (normA == 0) return;

    double ax = accel.x / normA;
    double ay = accel.y / normA;
    double az = accel.z / normA;

    double pitch = atan2(-ax, sqrt(ay * ay + az * az));
    double roll  = atan2(ay, az);

    double mx = mag.x;
    double my = mag.y;
    double mz = mag.z;

    double magXComp = mx * cos(pitch) + my * sin(pitch) * sin(roll) + mz * sin(pitch) * cos(roll);
    double magYComp = my * cos(roll) - mz * sin(roll);

    double yaw = atan2(-magYComp, magXComp);

    if (_lastYaw != null && _lastYawTimestamp != null) {
      final dt = now.difference(_lastYawTimestamp!).inMicroseconds / 1e6;
      if (dt > 0) {
        double dYaw = yaw - _lastYaw!;
        if (dYaw > pi) dYaw -= 2 * pi;
        if (dYaw < -pi) dYaw += 2 * pi;

        double yawRate = dYaw / dt;
        _yawRateBuffer.add(TimeStampedValue(now, yawRate));
      }
    }

    _lastYaw = yaw;
    _lastYawTimestamp = now;

    while (_yawRateBuffer.isNotEmpty && now.difference(_yawRateBuffer.first.time).inSeconds >= 1) {
      _yawRateBuffer.removeFirst();
    }

    _detectTurn();
  }

  Future<void> _checkStressTriggers(String userId) async {
    if (_isTrackMode) return; // MUTE NANNY

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
      _coachingService.triggerFeedback(
        message: body,
        vibrationPattern: [0, 200],
      );
      _hasWarnedAboutTimeTrigger = true;
      debugPrint('⚠️ Preventative Alert (haptic+voice): $title');
    });
  }

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

    if (magnitude < magnitudeSettledThreshold) {
      _isDecelerating       = false;
      _reversalConfirmCount = 0;
      _lastDirectionX       = currentX;
      _lastDirectionY       = currentY;
      _lastDirectionZ       = currentZ;
      return;
    }

    final dotProduct = (_lastDirectionX! * currentX) + (_lastDirectionY! * currentY) + (_lastDirectionZ! * currentZ);

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
      _reversalConfirmCount++;
      if (_reversalConfirmCount >= _kReversalHysteresisCount && !_isDecelerating) {
        _isDecelerating = true;
      }
    } else {
      _reversalConfirmCount = 0;
      if (magnitude < magnitudeSettledThreshold && _isDecelerating) {
        _isDecelerating = false;
      }
    }

    _lastDirectionX = currentX;
    _lastDirectionY = currentY;
    _lastDirectionZ = currentZ;
  }

  // ==================== TURN DETECTION ====================

  void _detectTurn() {
    if (_isTrackMode) return; // MUTE NANNY

    if (_yawRateBuffer.isEmpty || currentSpeedKmh < _t.minSpeedThresholdKmh) {
      _resetTurnState();
      return;
    }

    if (_lastTurnDetection != null &&
        DateTime.now().difference(_lastTurnDetection!) <
            Duration(seconds: _t.turnCooldownSeconds)) {
      return;
    }

    double meanYawRate = _yawRateBuffer.map((e) => e.value).reduce((a, b) => a + b) / _yawRateBuffer.length;

    if (meanYawRate.abs() > _t.yawRateThreshold) {
      if (_turnStartTime == null) {
        _turnStartTime  = DateTime.now();
        _turnEntrySpeed = currentSpeedKmh;
        _turnPeakYawRate = meanYawRate.abs();
      } else if (meanYawRate.abs() > _turnPeakYawRate) {
        _turnPeakYawRate = meanYawRate.abs();
      }

      final durationMs = DateTime.now().difference(_turnStartTime!).inMilliseconds;

      if (durationMs >= _t.turnDurationMs) {
        if (_useGyroscopeFusion) {
          if (_smoothedGyroZ.abs() <= _t.gyroRotationThreshold) {
            _resetTurnState();
            return;
          }
        }

        final direction = meanYawRate > 0 ? 'Right' : 'Left';
        if (direction == 'Left') {
          _sessionService.incrementLeftTurn();
        } else {
          _sessionService.incrementRightTurn();
        }

        _analyzeTurnQuality(
            _turnEntrySpeed ?? currentSpeedKmh, currentSpeedKmh, _turnPeakYawRate);
        _feedbackService.evaluateTurn(_turnPeakYawRate, currentSpeedKmh);

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
    _turnPeakYawRate = 0.0;
  }

  bool _shouldSendHaptic(DateTime? lastTime) {
    if (lastTime == null) return true;
    return DateTime.now().difference(lastTime) >
        Duration(seconds: _t.notificationCooldownSeconds);
  }

  void _checkCrashFromAcceleration(
      BuildContext context,
      WidgetRef ref,
      double avgMagnitude,
      ) {
    if (_isTrackMode) return; // MUTE NANNY

    if (_lastCrashDetection != null &&
        DateTime.now().difference(_lastCrashDetection!) <
            Duration(seconds: _t.crashCooldownSeconds)) return;
    if (_rawAccelMagnitudes.length < 2) return;

    final accelFluctuation =
        _rawAccelMagnitudes[_rawAccelMagnitudes.length - 1].abs() -
            _rawAccelMagnitudes[_rawAccelMagnitudes.length - 2].abs();

    if (accelFluctuation.abs() > _t.crashAccelFluctuationLimit) {
      _triggerCrashDetection(context, ref);
    }
  }

  void _checkCrashFromSpeedDrop(BuildContext context, WidgetRef ref) {
    if (_isTrackMode) return; // MUTE NANNY

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

    sendNotification('Crash Detected', 'Possible impact detected');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        CrashDetector.checkForCrash(context, ref, onDialogClosed: () {
          debugPrint('Crash dialog closed');
        });
      }
    });
  }

  Future<void> stopMonitoring(WidgetRef ref, {double? manualMileage}) async {
    _accelSub?.cancel();
    _magSub?.cancel();
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

        if (!_isTrackMode) {
          // =====================================
          // CITY NANNY SESSION SAVE
          // =====================================
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
        } else {
          // =====================================
          // TRACK MODE SESSION SAVE
          // =====================================
          // Hypothetical hook to retrieve the racing data map for the session
          // final lapData = _telemetryService.getLapData();

          _showSnack('🏁 Track Session Saved', Colors.greenAccent);
          debugPrint('🏁 Track session successfully ended.');
        }
      } catch (e) {
        debugPrint('Failed to update vehicle data: $e');
        _showSnack('❌ Error: ${e.toString()}', Colors.red);
      }
    }

    sendNotification('RAXXY', _isTrackMode ? 'Track Mode Stopped' : 'Monitoring service stopped');

    ref.read(vehicleMonitorProvider.notifier).clear();
    _monitoringContext = null;
    debugPrint('Monitoring stopped');
  }

  void _showSnack(String message, Color color) {
    if (_monitoringContext != null && _monitoringContext!.mounted) {
      showAppSnackBar(
        _monitoringContext!,
        message,
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      );
    }
  }

  void _analyzeTurnQuality(double entrySpeed, double exitSpeed, double peakYawRate) {
    String quality = 'Normal';
    String reason  = '';
    final speedDrop = entrySpeed - exitSpeed;

    if (peakYawRate > _t.jerkyTurnLimit) {
      quality = 'Jerky';
      reason  = 'High Yaw Rate (${peakYawRate.toStringAsFixed(1)} rad/s)';
    } else if (speedDrop > _t.significantSpeedDrop) {
      quality = 'Jerky';
      reason  = 'Hard Braking in Turn (-${speedDrop.toStringAsFixed(1)} km/h)';
    } else if (peakYawRate < _t.smoothTurnLimit && speedDrop < 10.0) {
      quality = 'Smooth';
      reason  = 'Controlled & Steady';
    }

    _sessionService.recordTurnQuality(quality);
    debugPrint(
      '🏁 Turn Quality: $quality | $reason | '
          'Entry: ${entrySpeed.toStringAsFixed(1)} → Exit: ${exitSpeed.toStringAsFixed(1)}',
    );

    if (quality == 'Jerky' && _shouldSendHaptic(_lastHarshAccelNotification)) {
      _coachingService.triggerFeedback(
        message: 'Watch your cornering.',
        vibrationPattern: [0, 100, 50, 100, 50, 100],
      );
    }
  }

  void _calculateAccidentRisk(WidgetRef ref) {
    if (_isTrackMode) return; // MUTE NANNY

    double risk = 0;
    if (currentSpeedKmh > 80)                  risk += 25;
    if (_sessionService.harshAccelEvents > 2)  risk += 20;
    if (_sessionService.harshBrakeEvents > 2)  risk += 20;
    final hour = DateTime.now().hour;
    if (hour >= 22 || hour < 5)                risk += 10;
    if (_turnPeakYawRate > 4.5)                risk += 15;

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