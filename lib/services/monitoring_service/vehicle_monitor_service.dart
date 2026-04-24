import 'dart:async';
import 'dart:math';
import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_sms/flutter_sms.dart';
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

// Import the new Racing Telemetry Service
import 'package:raxxy/services/racing_telemetary_core.dart';

import '../telemetry_logger_service.dart';


// Helper classes for sliding windows
class TimeStampedValue {
  final DateTime time;
  final double value;
  TimeStampedValue(this.time, this.value);
}

class VehicleMonitorService {
  // ==============================================================================
  // 🔧 RUNTIME THRESHOLDS
  // Loaded from SensorThresholdsProvider when startMonitoring() is called.
  // Defaults match the original hardcoded constants exactly.
  // ==============================================================================
  late SensorThresholds _t;

  // NEW: Dynamic Multipliers from DriverProfileService
  double _jerkMultiplier = 1.0;
  double _yawMultiplier = 1.0;

  // Fixed internal constant — LPF smoothing, not user-configurable
  static const double _kLpfAlpha = 0.15;

  // UI Specific LPF (Heavy smoothing to cancel engine vibration before math)
  static const double _kLpfAlphaUi = 0.05;
  double _uiLpfX = 0.0;
  double _uiLpfY = 0.0;
  double _uiLpfZ = 0.0;
  double _smoothedUiAcceleration = 0.0;

  // Minimum GPS speed (km/h) below which direction-reversal logic is skipped.
  static const double _kMinSpeedForReversalKmh = 3.0;

  // Number of consecutive samples the reversal angle must persist before we
  // commit to _isDecelerating = true.  Prevents single-spike false positives.
  static const int _kReversalHysteresisCount = 3;

  // ==================== STATE ====================
  bool _isTrackMode = false;
  final RacingTelemetryService _telemetryService = RacingTelemetryService();
  RacingTelemetryService get telemetry => _telemetryService;

  // NEW: Telemetry Logger Instance
  final TelemetryLogger _logger = TelemetryLogger();

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

  // Need to hold onto absolute accel buffers for crash detection
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

  // ==================== TURN DETECTION (YAW RATE) ====================
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

  // Hysteresis counter
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
    bool                  trackMode = false,
  }) async {
    _t = ref.read(sensorThresholdsProvider);
    _isTrackMode = trackMode;

    _turnStartTime        = null;
    _lastTurnDetection    = null;
    _turnPeakYawRate      = 0.0;

    _hasWarnedAboutTimeTrigger = false;
    _activeTriggers            = [];
    _lowSpeedCounter           = 0;

    // Reset multipliers & UI smoothing to baseline
    _jerkMultiplier = 1.0;
    _yawMultiplier = 1.0;
    _uiLpfX = 0.0;
    _uiLpfY = 0.0;
    _uiLpfZ = 0.0;
    _smoothedUiAcceleration = 0.0;

    if (_isMonitoring) return;
    _isMonitoring      = true;
    _userId            = userId;
    _vehicleId         = vehicleId;
    _monitoringContext = context;

    _sessionService.startSession();
    _telemetryService.reset(); // Reset telemetry engine
    await _logger.startLogging(); // NEW: Start the CSV logger

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
    if (!_isTrackMode) {
      _fetchDynamicThresholdModifiers(userId); // Fetch personalized thresholds only in normal mode
    }

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

    // UI update timer (500 ms) - Heavy math stays here to prevent stuttering
    _uiUpdateTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {

      if (!_isTrackMode) {
        // 1. Calculate and evaluate Jerk StdDev twice a second (Normal Mode)
        if (_jerkBuffer.length >= 10 && currentSpeedKmh > _t.minSpeedThresholdKmh) {
          double meanJerk = _jerkBuffer.map((e) => e.value).reduce((a, b) => a + b) / _jerkBuffer.length;
          double variance = _jerkBuffer.map((e) => pow(e.value - meanJerk, 2)).reduce((a, b) => a + b) / _jerkBuffer.length;
          double jerkStdDev = sqrt(variance);

          // Apply dynamic driver-specific multiplier
          final double jerkThreshold = _t.jerkStdDevThreshold * _jerkMultiplier;

          if (jerkStdDev > jerkThreshold) {
            if (!_isDecelerating) { // Positive motion
              // ---- HARSH ACCELERATION ----
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
              // ---- HARSH BRAKING ----
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

      } else {
        // Track Mode Telemetry Evaluation
        if (currentAcceleration != null) {
          _telemetryService.processTrackTelemetry(
            currentSpeed: currentSpeedKmh,
            accelX: currentAcceleration!.x,
            accelY: currentAcceleration!.y,
            gyroZ: _useGyroscopeFusion ? _smoothedGyroZ : 0.0,
          );
        }
      }

      // 2. Standard UI updates (Now pushing isolated smoothed UI acceleration)
      ref.read(vehicleMonitorProvider.notifier).updateAcceleration(_smoothedUiAcceleration);
      ref.read(vehicleMonitorProvider.notifier).updateSpeed(currentSpeedKmh);
      ref.read(vehicleMonitorProvider.notifier).updateDistance(totalDistanceMeters);
      _sessionService.updateSpeed(currentSpeedKmh);

      if (!_isTrackMode) {
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
      }
    });

    // ==================== MAGNETOMETER ====================
    _magSub = magnetometerEvents.listen((event) {
      _logger.logMagnetometer(event); // NEW: Log magnetometer event
      currentMagnetometer = event;
    });

    // ==================== ACCELEROMETER & EVENT MATH ====================
    _accelSub = userAccelerometerEvents.listen((event) {
      _logger.logAccelerometer(event); // NEW: Log accelerometer event

      final now = DateTime.now();
      currentAcceleration = event;

      // 1. Calculate Acceleration Magnitude Invariant |a(t)|
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

      // Jerk calculation with dt clamping
      if (_lastMagnitude != null && _lastAccelTimestamp != null) {
        final dt = now.difference(_lastAccelTimestamp!).inMicroseconds / 1e6; // in seconds

        // Ignore micro-updates faster than 10ms to prevent division-by-zero or infinity spikes
        if (dt > 0.01) {
          final jerk = (signedAcceleration - _lastMagnitude!) / dt;
          _jerkBuffer.add(TimeStampedValue(now, jerk));
          _lastMagnitude = signedAcceleration;
          _lastAccelTimestamp = now;
        }
      } else {
        _lastMagnitude = signedAcceleration;
        _lastAccelTimestamp = now;
      }

      // Purge jerk values older than 1 second (rolling window)
      while (_jerkBuffer.isNotEmpty && now.difference(_jerkBuffer.first.time).inSeconds >= 1) {
        _jerkBuffer.removeFirst();
      }

      // --------------------------------------------------------------------------
      // NEW: UI Specific Axis-First LPF to cancel zero-mean engine vibration
      // --------------------------------------------------------------------------
      _uiLpfX = (_kLpfAlphaUi * event.x) + ((1 - _kLpfAlphaUi) * _uiLpfX);
      _uiLpfY = (_kLpfAlphaUi * event.y) + ((1 - _kLpfAlphaUi) * _uiLpfY);
      _uiLpfZ = (_kLpfAlphaUi * event.z) + ((1 - _kLpfAlphaUi) * _uiLpfZ);

      double uiMagnitude = sqrt(_uiLpfX * _uiLpfX + _uiLpfY * _uiLpfY + _uiLpfZ * _uiLpfZ);
      _smoothedUiAcceleration = _isDecelerating ? -uiMagnitude : uiMagnitude;
      // --------------------------------------------------------------------------

      // Earth-Relative Yaw Calculation
      if (currentMagnetometer != null) {
        _calculateAndProcessYaw(event, currentMagnetometer!, now);
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
      debugPrint('✅ Gyroscope fusion enabled');
    }

    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 1,
      ),
    ).listen((position) {
      _logger.logGps(position); // NEW: Log GPS position

      // Ignore garbage indoor GPS bounces
      if (position.accuracy > 20.0) {
        debugPrint('Ignoring poor GPS signal: ${position.accuracy}m accuracy');
        return;
      }

      final now = DateTime.now();
      currentSpeedKmh = position.speed * 3.6;

      if (!_isTrackMode) {
        _speedHistory.add({'time': now, 'speed': currentSpeedKmh});
        if (_speedHistory.length > 10) _speedHistory.removeAt(0);

        if (crashFeature == true && _speedHistory.length >= 2) {
          _checkCrashFromSpeedDrop(context, ref);
        }
      } else {
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

  // ==================== FETCH PERSONALIZED THRESHOLDS ====================
  Future<void> _fetchDynamicThresholdModifiers(String userId) async {
    try {
      final profile = await DriverProfileService.getCachedProfile(userId);
      if (profile != null && profile['thresholdModifiers'] != null) {
        final mods = profile['thresholdModifiers'];
        _jerkMultiplier = (mods['jerkThresholdMultiplier'] ?? 1.0).toDouble();
        _yawMultiplier = (mods['yawThresholdMultiplier'] ?? 1.0).toDouble();

        debugPrint('🔧 Applied Personalized Baseline Modifiers — Jerk: $_jerkMultiplier, Yaw: $_yawMultiplier');
      }
    } catch (e) {
      debugPrint('Failed to load threshold modifiers: $e');
    }
  }

  // ==================== YAW CALCULATION (Earth-Relative) ====================
  void _calculateAndProcessYaw(UserAccelerometerEvent accel, MagnetometerEvent mag, DateTime now) {
    // 1. Calculate Pitch and Roll from Gravity Vector (Accelerometer)
    double normA = sqrt(accel.x * accel.x + accel.y * accel.y + accel.z * accel.z);
    if (normA == 0) return;

    double ax = accel.x / normA;
    double ay = accel.y / normA;
    double az = accel.z / normA;

    double pitch = atan2(-ax, sqrt(ay * ay + az * az));
    double roll  = atan2(ay, az);

    // 2. Extract Yaw Angle (rotation around Z-axis of Earth)
    // using Magnetometer and rotation matrix compensation
    double mx = mag.x;
    double my = mag.y;
    double mz = mag.z;

    double magXComp = mx * cos(pitch) + my * sin(pitch) * sin(roll) + mz * sin(pitch) * cos(roll);
    double magYComp = my * cos(roll) - mz * sin(roll);

    double yaw = atan2(-magYComp, magXComp);

    // 3. Calculate Yaw Rate
    if (_lastYaw != null && _lastYawTimestamp != null) {
      final dt = now.difference(_lastYawTimestamp!).inMicroseconds / 1e6; // seconds
      if (dt > 0) {
        // Handle wrapping around PI / -PI
        double dYaw = yaw - _lastYaw!;
        if (dYaw > pi) dYaw -= 2 * pi;
        if (dYaw < -pi) dYaw += 2 * pi;

        double yawRate = dYaw / dt;
        _yawRateBuffer.add(TimeStampedValue(now, yawRate));
      }
    }

    _lastYaw = yaw;
    _lastYawTimestamp = now;

    // Maintain 1-second rolling window
    while (_yawRateBuffer.isNotEmpty && now.difference(_yawRateBuffer.first.time).inSeconds >= 1) {
      _yawRateBuffer.removeFirst();
    }

    _detectTurn();
  }

  Future<void> _checkStressTriggers(String userId) async {
    if (_isTrackMode) return;

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
        debugPrint('🔴 Direction Reversal confirmed after $_reversalConfirmCount samples — DECELERATION mode');
      }
    } else {
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

  void _detectTurn() {
    if (_isTrackMode) return;

    if (_yawRateBuffer.isEmpty || currentSpeedKmh < _t.minSpeedThresholdKmh) {
      _resetTurnState();
      return;
    }

    if (_lastTurnDetection != null &&
        DateTime.now().difference(_lastTurnDetection!) <
            Duration(seconds: _t.turnCooldownSeconds)) {
      return;
    }

    // Mean Yaw Rate over the 1-second window
    double meanYawRate = _yawRateBuffer.map((e) => e.value).reduce((a, b) => a + b) / _yawRateBuffer.length;

    // Apply dynamic driver-specific multiplier
    if (meanYawRate.abs() > (_t.yawRateThreshold * _yawMultiplier)) {
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
            debugPrint('⚠️ Turn rejected: no gyro rotation');
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

        debugPrint(
          '🔄 Turn: $direction | Peak Yaw Rate: ${_turnPeakYawRate.toStringAsFixed(2)} rad/s | '
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
    if (_isTrackMode) return;

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
    if (_isTrackMode) return;

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

    await _logger.stopAndExport(); // NEW: Stop the logger and open share dialog

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

          // =================================================================
          // 🛑 NEW: GUARDIAN SAFETY FEATURE (AUTO SMS)
          // =================================================================
          try {
            // 1. Fetch user data to check age
            final userDoc = await firestore.collection('users').doc(_userId).get();
            if (userDoc.exists) {
              final age = userDoc.data()?['age'];
              final guardianContact = userDoc.data()?['guardianContact'];

              // 2. Check if minor AND has a guardian contact
              if (age != null && age < 18 && guardianContact != null && guardianContact.toString().isNotEmpty) {

                final driverName = userDoc.data()?['name'] ?? 'The driver';
                final dist = (totalDistanceMeters / 1000).toStringAsFixed(1);
                final maxSpd = summary['maxSpeedKmh']?.toStringAsFixed(0) ?? '0';
                final hBrakes = summary['harshBrakes'] ?? 0;
                final hAccels = summary['harshAccelerations'] ?? 0;

                // 3. Format the SMS
                String smsMessage = "🛡️ RAXXY Guardian Alert:\n"
                    "$driverName has finished driving.\n"
                    "• Distance: $dist km\n"
                    "• Max Speed: $maxSpd km/h\n"
                    "• Harsh Brakes: $hBrakes\n"
                    "• Harsh Accels: $hAccels";

                // 4. Send the SMS silently in the background
                try {

                  await sendSMS(
                    message: smsMessage,
                    recipients: [guardianContact],
                    sendDirect: true,
                  );
                  debugPrint("✅ Guardian Summary SMS sent successfully!");
                } catch (smsError) {
                  debugPrint("❌ Failed to send Guardian SMS: $smsError");
                }
              }
            }
          } catch (e) {
            debugPrint("❌ Error checking guardian status: $e");
          }
          // =================================================================

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
          _showSnack('🏁 Track Session Saved', Colors.greenAccent);
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

    // Apply dynamic driver-specific multiplier to turn quality limits
    if (peakYawRate > (_t.jerkyTurnLimit * _yawMultiplier)) {
      quality = 'Jerky';
      reason  = 'High Yaw Rate (${peakYawRate.toStringAsFixed(1)} rad/s)';
    } else if (speedDrop > _t.significantSpeedDrop) {
      quality = 'Jerky';
      reason  = 'Hard Braking in Turn (-${speedDrop.toStringAsFixed(1)} km/h)';
    } else if (peakYawRate < (_t.smoothTurnLimit * _yawMultiplier) && speedDrop < 10.0) {
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
    if (_isTrackMode) return;

    double risk = 0;
    if (currentSpeedKmh > 80)                  risk += 25;
    if (_sessionService.harshAccelEvents > 2)  risk += 20;
    if (_sessionService.harshBrakeEvents > 2)  risk += 20;
    final hour = DateTime.now().hour;
    if (hour >= 22 || hour < 5)                risk += 10;

    // Apply dynamic driver-specific multiplier to accident risk turn penalty
    if (_turnPeakYawRate > (1.2 * _yawMultiplier)) risk += 15;

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