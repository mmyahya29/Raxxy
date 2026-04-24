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

  // Dynamic Multipliers from DriverProfileService
  double _jerkMultiplier = 1.0;
  double _yawMultiplier  = 1.0;

  // Fixed internal constant — LPF smoothing for event detection (moderate)
  // BUG 6 FIX: Single pipeline used for both display and detection, alpha=0.2
  static const double _kLpfAlpha   = 0.15;
  static const double _kLpfAlphaUi = 0.20; // was 0.05 (over-smoothed display) — now moderate

  // BUG 3 FIX: Gravity LPF — high alpha keeps gravity stable (slow-moving component)
  static const double _kGravityAlpha = 0.98;

  // Gravity vector estimate (phone-frame, m/s²). Initialised from first accel sample.
  double _gravX = 0.0;
  double _gravY = 0.0;
  double _gravZ = 9.81;

  // BUG 16 FIX: Gyro fusion uses a more responsive alpha (0.5 instead of 0.15)
  static const double _kGyroAlpha = 0.50;

  // UI smoothed axes (after gravity removal)
  double _uiLpfX = 0.0;
  double _uiLpfY = 0.0;
  double _uiLpfZ = 0.0;
  double _smoothedUiAcceleration = 0.0;

  // Minimum GPS speed (km/h) below which direction-reversal logic is skipped.
  static const double _kMinSpeedForReversalKmh = 3.0;

  // BUG 1 FIX: Hysteresis count for confirming reversal (entry) and re-entry (exit).
  static const int _kReversalHysteresisCount = 3;
  static const int _kAccelReentryCount       = 3; // samples below threshold to exit decel mode

  // ==================== STATE ====================
  bool _isTrackMode = false;
  final RacingTelemetryService _telemetryService = RacingTelemetryService();
  RacingTelemetryService get telemetry => _telemetryService;

  final TelemetryLogger _logger = TelemetryLogger();

  // ==================== ACCIDENT RISK ====================
  double   _currentRiskScore = 0;
  String   _currentRiskLevel = 'Low';
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
  Timer? _speedZoneTimer; // BUG 17: field retained — implement or remove as needed

  UserAccelerometerEvent? currentAcceleration;
  MagnetometerEvent?      currentMagnetometer;
  double currentSpeedKmh = 0.0;

  // BUG 13 FIX: crashFeature stored as class field, updated via Riverpod listener
  bool _crashFeatureEnabled = false;

  final List<Map<String, dynamic>> _speedHistory = [];

  double    totalDistanceMeters = 0.0;
  Position? _lastPosition;
  bool      _isMonitoring = false;

  // ==================== JERK STANDARD DEVIATION ====================
  final Queue<TimeStampedValue> _jerkBuffer = Queue();

  // BUG 6 FIX: Separate last-magnitude for jerk pipeline (uses gravity-removed linear accel)
  double?   _lastLinearMagnitude;
  DateTime? _lastAccelTimestamp;

  // Need to hold onto absolute accel buffers for crash detection
  // BUG 10 FIX: stores unsigned magnitude only
  final List<double> _rawAccelMagnitudes = [];

  // BUG 18 FIX: sustainedSampleCount raised to 3 (requires 1.5 s of sustained harsh behaviour)
  final int sustainedSampleCount = 3;

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

  // ==================== TURN DETECTION (YAW RATE — GPS-primary) ====================
  // BUG 7 FIX: Primary yaw source is GPS bearing change (no magnetometer bias).
  // Magnetometer path kept as fallback when GPS speed is too low.
  final Queue<TimeStampedValue> _yawRateBuffer = Queue();

  // GPS-bearing yaw
  double?   _lastGpsBearing;
  DateTime? _lastGpsBearingTimestamp;

  // Magnetometer-compass yaw (fallback when GPS slow)
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
  // BUG 1+2 FIX: direction state uses gravity-removed linear accel vector.
  // Anchor vector is locked at the moment reversal suspicion begins and held
  // for the full hysteresis window.
  double? _anchorLinX;
  double? _anchorLinY;
  double? _anchorLinZ;
  bool    _isDecelerating        = false;
  int     _reversalConfirmCount  = 0;
  int     _accelReentryCount     = 0; // counts samples after reversal exits threshold

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
    _t           = ref.read(sensorThresholdsProvider);
    _isTrackMode = trackMode;

    _turnStartTime     = null;
    _lastTurnDetection = null;
    _turnPeakYawRate   = 0.0;

    _hasWarnedAboutTimeTrigger = false;
    _activeTriggers            = [];
    _lowSpeedCounter           = 0;

    // Reset multipliers & smoothing to baseline
    _jerkMultiplier = 1.0;
    _yawMultiplier  = 1.0;
    _uiLpfX = 0.0;
    _uiLpfY = 0.0;
    _uiLpfZ = 0.0;
    _smoothedUiAcceleration = 0.0;

    // BUG 3 FIX: Reset gravity estimate
    _gravX = 0.0;
    _gravY = 0.0;
    _gravZ = 9.81;

    if (_isMonitoring) return;
    _isMonitoring      = true;
    _userId            = userId;
    _vehicleId         = vehicleId;
    _monitoringContext = context;

    _sessionService.startSession();
    _telemetryService.reset();
    await _logger.startLogging();

    _lastCrashDetection    = null;
    _consecutiveHarshAccel = 0;
    _consecutiveHarshBrake = 0;
    _lastTurnDetection     = null;

    // BUG 1+2 FIX: Reset anchor-based direction state
    _anchorLinX           = null;
    _anchorLinY           = null;
    _anchorLinZ           = null;
    _isDecelerating       = false;
    _reversalConfirmCount = 0;
    _accelReentryCount    = 0;

    // GPS bearing yaw state
    _lastGpsBearing          = null;
    _lastGpsBearingTimestamp = null;

    // Magnetometer yaw state (fallback)
    _lastYaw          = null;
    _lastYawTimestamp = null;

    _jerkBuffer.clear();
    _yawRateBuffer.clear();
    _lastLinearMagnitude = null;
    _lastAccelTimestamp  = null;
    _rawAccelMagnitudes.clear();

    // BUG 13 FIX: Read crash feature at session start and keep it updated
    _crashFeatureEnabled = ref.read(featureNotifierProvider) ?? false;
    ref.listenManual(featureNotifierProvider, (_, next) {
      _crashFeatureEnabled = next ?? false;
    });

    ref.read(vehicleMonitorProvider.notifier).setVehicle(vehicleId);
    ref.read(vehicleMonitorProvider.notifier).setMake(make);
    ref.read(vehicleMonitorProvider.notifier).setModel(model);

    sendNotification('RAXXY', _isTrackMode ? 'Track Mode Active' : 'Monitoring service started');
    debugPrint('RAXXY: Monitoring service started. Track Mode: $_isTrackMode');

    _checkStressTriggers(userId);

    if (!_isTrackMode) {
      // BUG 12 FIX: Await threshold fetch before sensors start so multipliers
      // are stable from the first sample; no stale-state race condition.
      await _fetchDynamicThresholdModifiers(userId);
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

    // UI update timer (500 ms) — heavy math evaluated here at a controlled rate
    _uiUpdateTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {

      // BUG 14 FIX: Recalculate accident risk every 500 ms so speed/events are live
      if (!_isTrackMode) {
        _calculateAccidentRisk(ref);
      }

      if (!_isTrackMode) {
        // BUG 5 FIX: use millisecond precision for window boundary and evaluate
        // only when buffer has a meaningful minimum of samples.
        if (_jerkBuffer.length >= 10 && currentSpeedKmh > _t.minSpeedThresholdKmh) {
          final double meanJerk =
              _jerkBuffer.map((e) => e.value).reduce((a, b) => a + b) /
                  _jerkBuffer.length;
          final double variance =
              _jerkBuffer.map((e) => pow(e.value - meanJerk, 2)).reduce((a, b) => a + b) /
                  _jerkBuffer.length;
          final double jerkStdDev = sqrt(variance);

          // Apply dynamic driver-specific multiplier
          final double jerkThreshold = _t.jerkStdDevThreshold * _jerkMultiplier;

          if (jerkStdDev > jerkThreshold) {
            if (!_isDecelerating) {
              // ---- HARSH ACCELERATION ----
              _consecutiveHarshAccel++;
              _consecutiveHarshBrake = 0;
              _sessionService.updateAccelDecelState('accel');

              // BUG 18 FIX: sustainedSampleCount is now 3 — real hysteresis
              if (_consecutiveHarshAccel >= sustainedSampleCount &&
                  _shouldSendHaptic(_lastHarshAccelNotification)) {
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

              if (_consecutiveHarshBrake >= sustainedSampleCount &&
                  _shouldSendHaptic(_lastHarshBrakeNotification)) {
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

          // BUG 13 FIX: use instance field (always current) instead of stale closure
          if (_crashFeatureEnabled) {
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

      // Standard UI updates — push isolated smoothed UI acceleration
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
      _logger.logMagnetometer(event);
      currentMagnetometer = event;
    });

    // ==================== ACCELEROMETER & EVENT MATH ====================
    _accelSub = userAccelerometerEvents.listen((event) {
      _logger.logAccelerometer(event);

      final now = DateTime.now();
      currentAcceleration = event;

      // ------------------------------------------------------------------
      // BUG 3 FIX: Gravity removal using high-alpha LPF.
      // Gravity is the slow (DC) component; we track it with alpha=0.98.
      // Linear (motion) acceleration = raw - gravity estimate.
      // ------------------------------------------------------------------
      _gravX = _kGravityAlpha * _gravX + (1 - _kGravityAlpha) * event.x;
      _gravY = _kGravityAlpha * _gravY + (1 - _kGravityAlpha) * event.y;
      _gravZ = _kGravityAlpha * _gravZ + (1 - _kGravityAlpha) * event.z;

      final double linX = event.x - _gravX;
      final double linY = event.y - _gravY;
      final double linZ = event.z - _gravZ;

      // Unsigned linear magnitude (gravity-removed)
      final double linearMagnitude = sqrt(linX * linX + linY * linY + linZ * linZ);

      // ------------------------------------------------------------------
      // Direction reversal on gravity-removed linear acceleration
      // ------------------------------------------------------------------
      if (currentSpeedKmh > _kMinSpeedForReversalKmh) {
        _detectDirectionReversal(linX, linY, linZ, linearMagnitude);
      } else {
        // Below min speed: neutral state, no reversal
        _isDecelerating       = false;
        _reversalConfirmCount = 0;
        _accelReentryCount    = 0;
        _anchorLinX           = null;
        _anchorLinY           = null;
        _anchorLinZ           = null;
      }

      // BUG 4 FIX: Signed acceleration derived from gravity-removed linear accel.
      // Sign flip is now based on a stable, hysteresis-gated flag — not noisy
      // raw magnitude — so flip artifacts are eliminated.
      final double signedAcceleration = _isDecelerating ? -linearMagnitude : linearMagnitude;

      // BUG 10 FIX: Crash detection buffer stores UNSIGNED magnitude only.
      _rawAccelMagnitudes.add(linearMagnitude);
      if (_rawAccelMagnitudes.length > 5) _rawAccelMagnitudes.removeAt(0);

      // ------------------------------------------------------------------
      // Jerk calculation with dt clamping
      // BUG 5 FIX: Uses gravity-removed linear magnitude for consistency.
      // ------------------------------------------------------------------
      if (_lastLinearMagnitude != null && _lastAccelTimestamp != null) {
        final double dt =
            now.difference(_lastAccelTimestamp!).inMicroseconds / 1e6;

        if (dt > 0.01) {
          final double jerk = (signedAcceleration - _lastLinearMagnitude!) / dt;
          _jerkBuffer.add(TimeStampedValue(now, jerk));
          _lastLinearMagnitude = signedAcceleration;
          _lastAccelTimestamp  = now;
        }
      } else {
        _lastLinearMagnitude = signedAcceleration;
        _lastAccelTimestamp  = now;
      }

      // BUG 5 FIX: Purge uses milliseconds for sub-second precision
      while (_jerkBuffer.isNotEmpty &&
          now.difference(_jerkBuffer.first.time).inMilliseconds >= 1000) {
        _jerkBuffer.removeFirst();
      }

      // ------------------------------------------------------------------
      // BUG 6 FIX: UI smoothing pipeline uses gravity-removed axes with
      // moderate alpha (0.20) — same signal as detection, not a separate
      // over-smoothed pipeline. This makes the displayed value match reality.
      // ------------------------------------------------------------------
      _uiLpfX = (_kLpfAlphaUi * linX) + ((1 - _kLpfAlphaUi) * _uiLpfX);
      _uiLpfY = (_kLpfAlphaUi * linY) + ((1 - _kLpfAlphaUi) * _uiLpfY);
      _uiLpfZ = (_kLpfAlphaUi * linZ) + ((1 - _kLpfAlphaUi) * _uiLpfZ);

      final double uiMagnitude =
      sqrt(_uiLpfX * _uiLpfX + _uiLpfY * _uiLpfY + _uiLpfZ * _uiLpfZ);
      _smoothedUiAcceleration = _isDecelerating ? -uiMagnitude : uiMagnitude;

      // ------------------------------------------------------------------
      // BUG 7 FIX: Compass-yaw is now only the LOW-SPEED FALLBACK path.
      // Primary yaw comes from GPS bearing change (updated in GPS stream).
      // We still compute compass yaw here so it's ready when GPS is slow,
      // but it is NOT fed into the yaw rate buffer directly from here.
      // ------------------------------------------------------------------
      if (currentMagnetometer != null && currentSpeedKmh < 15.0) {
        _calculateCompassYawFallback(event, currentMagnetometer!, now);
      }
    });

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

    // BUG 16 FIX: Gyro uses more responsive alpha (0.50 instead of 0.15)
    if (_useGyroscopeFusion) {
      _gyroSub = gyroscopeEvents.listen((GyroscopeEvent event) {
        _logger.logGyroscope(event);
        _smoothedGyroZ =
            (_kGyroAlpha * event.z) + ((1 - _kGyroAlpha) * _smoothedGyroZ);
      });
      debugPrint('✅ Gyroscope fusion enabled');
    }

    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 1,
      ),
    ).listen((position) {
      _logger.logGps(position);

      // BUG 15 FIX: Tiered GPS accuracy.
      // Accept positions up to 50 m accuracy for speed/distance/yaw.
      // Only use positions < 15 m for crash speed-drop detection.
      if (position.accuracy > 50.0) {
        debugPrint('Ignoring poor GPS signal: ${position.accuracy}m accuracy');
        return;
      }

      final now = DateTime.now();
      currentSpeedKmh = position.speed * 3.6;

      // ------------------------------------------------------------------
      // BUG 7 FIX: Primary yaw rate from GPS bearing change.
      // GPS bearing is compass-true heading of motion — no magnetometer bias,
      // no hard/soft iron error, accurate at any speed > ~5 km/h.
      // ------------------------------------------------------------------
      if (!_isTrackMode && currentSpeedKmh >= _kMinSpeedForReversalKmh) {
        final double gpsBearing = position.heading; // degrees, 0–360
        if (_lastGpsBearing != null && _lastGpsBearingTimestamp != null) {
          final double dtSec =
              now.difference(_lastGpsBearingTimestamp!).inMilliseconds / 1000.0;
          if (dtSec > 0) {
            double dBearing = gpsBearing - _lastGpsBearing!;
            // Wrap to [-180, +180]
            if (dBearing > 180)  dBearing -= 360;
            if (dBearing < -180) dBearing += 360;

            // Convert bearing change (deg/s) to yaw rate (rad/s)
            final double yawRateRad = (dBearing * pi / 180.0) / dtSec;
            _yawRateBuffer.add(TimeStampedValue(now, yawRateRad));
          }
        }
        _lastGpsBearing          = gpsBearing;
        _lastGpsBearingTimestamp = now;
      }

      // BUG 8 FIX: Yaw buffer purged with millisecond precision
      while (_yawRateBuffer.isNotEmpty &&
          now.difference(_yawRateBuffer.first.time).inMilliseconds >= 1000) {
        _yawRateBuffer.removeFirst();
      }

      // Evaluate turn detection after updating yaw buffer from GPS
      if (!_isTrackMode) {
        _detectTurn();
      }

      if (!_isTrackMode) {
        _speedHistory.add({'time': now, 'speed': currentSpeedKmh});
        if (_speedHistory.length > 10) _speedHistory.removeAt(0);

        // BUG 13 FIX: use instance field, not stale closure
        // BUG 15 FIX: speed-drop crash check only when GPS is accurate enough
        if (_crashFeatureEnabled &&
            _speedHistory.length >= 2 &&
            position.accuracy < 15.0) {
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

    // BUG 14 FIX: _calculateAccidentRisk is now called in the 500ms timer above.
    // Initial call here still sets up the first reading at session open.
    _calculateAccidentRisk(ref);
    debugPrint('✅ Monitoring started');
  }

  // ==================== FETCH PERSONALIZED THRESHOLDS ====================
  // BUG 12 FIX: Made non-private async so startMonitoring can await it,
  // preventing the race where sensors fire before multipliers are loaded.
  Future<void> _fetchDynamicThresholdModifiers(String userId) async {
    try {
      final profile = await DriverProfileService.getCachedProfile(userId);
      if (profile != null && profile['thresholdModifiers'] != null) {
        final mods = profile['thresholdModifiers'];
        _jerkMultiplier =
            (mods['jerkThresholdMultiplier'] ?? 1.0).toDouble();
        _yawMultiplier  =
            (mods['yawThresholdMultiplier'] ?? 1.0).toDouble();
        debugPrint(
          '🔧 Applied Personalized Baseline Modifiers — '
              'Jerk: $_jerkMultiplier, Yaw: $_yawMultiplier',
        );
      }
    } catch (e) {
      debugPrint('Failed to load threshold modifiers: $e');
    }
  }

  // ==============================================================================
  // BUG 7 FIX: Compass yaw is now a LOW-SPEED FALLBACK only.
  // Called from accelerometer stream when GPS speed < 15 km/h.
  // Adds to the shared _yawRateBuffer so _detectTurn() works in both paths.
  // ==============================================================================
  void _calculateCompassYawFallback(
      UserAccelerometerEvent accel,
      MagnetometerEvent mag,
      DateTime now,
      ) {
    // 1. Tilt-compensated heading from accelerometer + magnetometer
    final double normA =
    sqrt(accel.x * accel.x + accel.y * accel.y + accel.z * accel.z);
    if (normA == 0) return;

    final double ax = accel.x / normA;
    final double ay = accel.y / normA;
    final double az = accel.z / normA;

    final double pitch = atan2(-ax, sqrt(ay * ay + az * az));
    final double roll  = atan2(ay, az);

    final double mx = mag.x;
    final double my = mag.y;
    final double mz = mag.z;

    final double magXComp =
        mx * cos(pitch) +
            my * sin(pitch) * sin(roll) +
            mz * sin(pitch) * cos(roll);
    final double magYComp = my * cos(roll) - mz * sin(roll);

    final double yaw = atan2(-magYComp, magXComp);

    // 2. Yaw rate from successive compass readings
    if (_lastYaw != null && _lastYawTimestamp != null) {
      final double dt =
          now.difference(_lastYawTimestamp!).inMicroseconds / 1e6;
      if (dt > 0) {
        double dYaw = yaw - _lastYaw!;
        if (dYaw > pi)  dYaw -= 2 * pi;
        if (dYaw < -pi) dYaw += 2 * pi;

        final double yawRate = dYaw / dt;
        _yawRateBuffer.add(TimeStampedValue(now, yawRate));
      }
    }

    _lastYaw          = yaw;
    _lastYawTimestamp = now;

    // BUG 8 FIX: millisecond precision purge
    while (_yawRateBuffer.isNotEmpty &&
        now.difference(_yawRateBuffer.first.time).inMilliseconds >= 1000) {
      _yawRateBuffer.removeFirst();
    }
  }

  // ==================== STRESS TRIGGERS ====================
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
      } else if (triggers.contains('Evening Traffic (4-10 PM)') &&
          hour >= 16 &&
          hour < 22) {
        _triggerPreventativeAlert('Evening Rush Detected',
            'Traffic might be heavy. Patience is your best fuel saver right now.');
      } else if (triggers.contains('Late Night Driving') &&
          (hour >= 22 || hour < 5)) {
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

  // ==============================================================================
  // DIRECTION REVERSAL DETECTION (gravity-removed linear acceleration)
  //
  // BUG 1 FIX: Explicit reset path — magnitude-settle exits decel mode
  //            regardless of angle, with a symmetric re-entry counter.
  // BUG 2 FIX: Anchor vector locked at first suspicion; held fixed for the
  //            entire hysteresis window so the reference doesn't drift.
  // BUG 3 FIX: Operates on gravity-removed linear accel (linX/Y/Z), not
  //            raw phone-frame axes.
  // BUG 4 FIX: Flag is hysteresis-gated; no single-sample flip artefacts.
  // ==============================================================================
  void _detectDirectionReversal(
      double linX,
      double linY,
      double linZ,
      double magnitude,
      ) {
    // --- Settle check: if net linear acceleration is negligible, neutral state ---
    if (magnitude < magnitudeSettledThreshold) {
      // BUG 1 FIX: Always reset decel flag on settle, irrespective of angle
      _isDecelerating       = false;
      _reversalConfirmCount = 0;
      _accelReentryCount    = 0;
      _anchorLinX           = null;
      _anchorLinY           = null;
      _anchorLinZ           = null;
      return;
    }

    // --- If we don't have an anchor yet, set it now ---
    if (_anchorLinX == null) {
      _anchorLinX = linX;
      _anchorLinY = linY;
      _anchorLinZ = linZ;
      return;
    }

    final double anchorMag = sqrt(
      _anchorLinX! * _anchorLinX! +
          _anchorLinY! * _anchorLinY! +
          _anchorLinZ! * _anchorLinZ!,
    );

    if (anchorMag < 0.01) {
      // Degenerate anchor — refresh it
      _anchorLinX = linX;
      _anchorLinY = linY;
      _anchorLinZ = linZ;
      return;
    }

    final double dotProduct =
        (_anchorLinX! * linX) +
            (_anchorLinY! * linY) +
            (_anchorLinZ! * linZ);

    final double cosTheta =
    (dotProduct / (anchorMag * magnitude)).clamp(-1.0, 1.0);
    final double angleDegrees = acos(cosTheta) * (180.0 / pi);

    if (!_isDecelerating) {
      // --- Trying to ENTER deceleration ---
      if (angleDegrees > directionReversalThreshold) {
        _reversalConfirmCount++;
        _accelReentryCount = 0;
        // BUG 2 FIX: Anchor is NOT updated during hysteresis window —
        // it stays locked to the pre-reversal direction for stable comparison.
        if (_reversalConfirmCount >= _kReversalHysteresisCount) {
          _isDecelerating       = true;
          _reversalConfirmCount = 0;
          // Commit anchor to current direction now that decel is confirmed
          _anchorLinX = linX;
          _anchorLinY = linY;
          _anchorLinZ = linZ;
          debugPrint('🔴 Deceleration confirmed — DECEL mode');
        }
      } else {
        // Angle not large enough — reset hysteresis and keep updating anchor
        _reversalConfirmCount = 0;
        _anchorLinX = linX;
        _anchorLinY = linY;
        _anchorLinZ = linZ;
      }
    } else {
      // --- Currently decelerating — watch for return to acceleration ---
      // BUG 1 FIX: Re-entry requires _kAccelReentryCount consecutive samples
      // below the reversal threshold (symmetric hysteresis on exit).
      if (angleDegrees <= directionReversalThreshold) {
        _accelReentryCount++;
        if (_accelReentryCount >= _kAccelReentryCount) {
          _isDecelerating       = false;
          _accelReentryCount    = 0;
          _reversalConfirmCount = 0;
          // Reset anchor to current direction for next detection cycle
          _anchorLinX = linX;
          _anchorLinY = linY;
          _anchorLinZ = linZ;
          debugPrint('🟢 Re-entry confirmed — ACCEL mode');
        }
        // Do NOT update anchor during re-entry hysteresis window
      } else {
        // Still decelerating — keep anchor current
        _accelReentryCount = 0;
        _anchorLinX        = linX;
        _anchorLinY        = linY;
        _anchorLinZ        = linZ;
      }
    }
  }

  // ==============================================================================
  // TURN DETECTION
  //
  // BUG 8 FIX: Evaluated from GPS stream (not 100Hz accel callback) so the
  //            evaluation rate matches the yaw buffer update rate.
  // BUG 9 FIX: Cooldown guard moved to AFTER the duration check so consecutive
  //            turns (S-curves) accumulate properly during the cooldown window.
  // ==============================================================================
  void _detectTurn() {
    if (_isTrackMode) return;

    if (_yawRateBuffer.isEmpty || currentSpeedKmh < _t.minSpeedThresholdKmh) {
      _resetTurnState();
      return;
    }

    // Mean Yaw Rate over the 1-second window
    final double meanYawRate =
        _yawRateBuffer.map((e) => e.value).reduce((a, b) => a + b) /
            _yawRateBuffer.length;

    // Apply dynamic driver-specific multiplier
    if (meanYawRate.abs() > (_t.yawRateThreshold * _yawMultiplier)) {
      if (_turnStartTime == null) {
        _turnStartTime   = DateTime.now();
        _turnEntrySpeed  = currentSpeedKmh;
        _turnPeakYawRate = meanYawRate.abs();
      } else if (meanYawRate.abs() > _turnPeakYawRate) {
        _turnPeakYawRate = meanYawRate.abs();
      }

      final int durationMs =
          DateTime.now().difference(_turnStartTime!).inMilliseconds;

      if (durationMs >= _t.turnDurationMs) {
        // Gyro fusion confirmation gate
        if (_useGyroscopeFusion) {
          if (_smoothedGyroZ.abs() <= _t.gyroRotationThreshold) {
            debugPrint('⚠️ Turn rejected: no gyro rotation');
            _resetTurnState();
            return;
          }
        }

        // BUG 9 FIX: Cooldown check is now here — AFTER duration is satisfied.
        // This lets the turn accumulate state during the cooldown window so
        // back-to-back turns are not silently swallowed.
        if (_lastTurnDetection != null &&
            DateTime.now().difference(_lastTurnDetection!) <
                Duration(seconds: _t.turnCooldownSeconds)) {
          // Cooldown active — reset and wait for next turn
          _resetTurnState();
          return;
        }

        final String direction = meanYawRate > 0 ? 'Right' : 'Left';
        if (direction == 'Left') {
          _sessionService.incrementLeftTurn();
        } else {
          _sessionService.incrementRightTurn();
        }

        _analyzeTurnQuality(
          _turnEntrySpeed ?? currentSpeedKmh,
          currentSpeedKmh,
          _turnPeakYawRate,
        );
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
    _turnStartTime   = null;
    _turnEntrySpeed  = null;
    _turnPeakYawRate = 0.0;
  }

  bool _shouldSendHaptic(DateTime? lastTime) {
    if (lastTime == null) return true;
    return DateTime.now().difference(lastTime) >
        Duration(seconds: _t.notificationCooldownSeconds);
  }

  // ==============================================================================
  // CRASH DETECTION — ACCELERATION
  //
  // BUG 10 FIX: Uses unsigned magnitude for fluctuation check.
  //             Sign flip artefacts from _isDecelerating no longer trigger
  //             false crash alerts.
  // ==============================================================================
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

    // BUG 10 FIX: Both values are unsigned — no sign-flip artefacts
    final double accelFluctuation =
        _rawAccelMagnitudes[_rawAccelMagnitudes.length - 1] -
            _rawAccelMagnitudes[_rawAccelMagnitudes.length - 2];

    if (accelFluctuation.abs() > _t.crashAccelFluctuationLimit) {
      _triggerCrashDetection(context, ref);
    }
  }

  // ==============================================================================
  // CRASH DETECTION — SPEED DROP
  //
  // BUG 11 FIX: delTime window widened to 2.5s and gated on GPS accuracy < 15m
  //             (accuracy gate enforced in the GPS stream before this is called).
  // ==============================================================================
  void _checkCrashFromSpeedDrop(BuildContext context, WidgetRef ref) {
    if (_isTrackMode) return;

    if (_lastCrashDetection != null &&
        DateTime.now().difference(_lastCrashDetection!) <
            Duration(seconds: _t.crashCooldownSeconds)) return;
    if (_speedHistory.length < 2) return;

    final recent   = _speedHistory[_speedHistory.length - 1];
    final previous = _speedHistory[_speedHistory.length - 2];

    final double delTime =
        (recent['time'] as DateTime)
            .difference(previous['time'] as DateTime)
            .inMilliseconds /
            1000.0;
    final double delSpeed =
        (recent['speed'] as double) - (previous['speed'] as double);

    // BUG 11 FIX: Widened delTime window to 2.5 s to handle GPS update gaps
    if (delSpeed < -_t.crashSpeedDropLimit && delTime < 2.5) {
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

    await _logger.stopAndExport();

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

        final double mileageToAdd =
            manualMileage ?? (totalDistanceMeters / 1000);

        await firestore.runTransaction((transaction) async {
          final snapshot = await transaction.get(vehicleDoc);
          if (snapshot.exists) {
            final currentMileage = snapshot.data()?['mileage'] ?? 0;
            transaction.update(vehicleDoc, {
              'mileage': currentMileage + mileageToAdd.round(),
            });
          }
        });

        _showSnack(
          '✅ Mileage updated: +${mileageToAdd.toStringAsFixed(2)} km',
          Colors.green,
        );
        await Future.delayed(const Duration(milliseconds: 500));

        if (!_isTrackMode) {
          await _sessionService.saveSummary(
            userId: _userId!,
            vehicleId: _vehicleId!,
            totalDistanceKm: totalDistanceMeters / 1000,
          );

          final summary =
          _sessionService.generateSummary(totalDistanceMeters / 1000);
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

    sendNotification(
      'RAXXY',
      _isTrackMode ? 'Track Mode Stopped' : 'Monitoring service stopped',
    );

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

  void _analyzeTurnQuality(
      double entrySpeed,
      double exitSpeed,
      double peakYawRate,
      ) {
    String quality = 'Normal';
    String reason  = '';
    final double speedDrop = entrySpeed - exitSpeed;

    if (peakYawRate > (_t.jerkyTurnLimit * _yawMultiplier)) {
      quality = 'Jerky';
      reason  = 'High Yaw Rate (${peakYawRate.toStringAsFixed(1)} rad/s)';
    } else if (speedDrop > _t.significantSpeedDrop) {
      quality = 'Jerky';
      reason  = 'Hard Braking in Turn (-${speedDrop.toStringAsFixed(1)} km/h)';
    } else if (peakYawRate < (_t.smoothTurnLimit * _yawMultiplier) &&
        speedDrop < 10.0) {
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

  // ==============================================================================
  // ACCIDENT RISK
  //
  // BUG 14 FIX: Now called from the 500ms timer — risk score is live.
  // ==============================================================================
  void _calculateAccidentRisk(WidgetRef ref) {
    if (_isTrackMode) return;

    double risk = 0;
    if (currentSpeedKmh > 80)                  risk += 25;
    if (_sessionService.harshAccelEvents > 2)  risk += 20;
    if (_sessionService.harshBrakeEvents > 2)  risk += 20;
    final int hour = DateTime.now().hour;
    if (hour >= 22 || hour < 5)                risk += 10;

    if (_turnPeakYawRate > (1.2 * _yawMultiplier)) risk += 15;

    _currentRiskScore = risk;
    _currentRiskLevel =
    risk <= 30 ? 'Low' : risk <= 60 ? 'Medium' : 'High';

    ref.read(vehicleMonitorProvider.notifier)
        .updateRisk(_currentRiskScore, _currentRiskLevel);

    if (_lastRiskAlert == null ||
        DateTime.now().difference(_lastRiskAlert!) > _kRiskCooldown) {
      _feedbackService.evaluateAccidentRisk(
          _currentRiskLevel, _currentRiskScore);
      _lastRiskAlert = DateTime.now();
    }
  }
}