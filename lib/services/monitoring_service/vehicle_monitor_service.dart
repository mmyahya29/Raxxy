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
  // ==============================================================================
  late SensorThresholds _t;

  // Dynamic Multipliers from DriverProfileService
  double _jerkMultiplier = 1.0;
  double _yawMultiplier  = 1.0;

  // ── LPF Alphas ──────────────────────────────────────────────────────────────
  // UI display smoothing — moderate, applied to gravity-removed linear axes.
  static const double _kLpfAlphaUi = 0.20;

  // FIX A — Gravity LPF alpha.
  // 0.98 was so slow that a phone mounted at any angle took ~2.5 s to converge,
  // causing a 7-10 m/s² idle reading.  0.90 converges in ~10 samples (~100 ms)
  // which is fast enough to not pollute the first jerk window while still
  // treating gravity as the DC component.
  static const double _kGravityAlpha = 0.90;

  // FIX B — Complementary filter: how much the gyroscope "corrects" the gravity
  // direction every sample. Prevents sustained cornering G from bleeding into
  // the gravity estimate and suppressing real acceleration to near-zero.
  // Formula:  grav_corrected = (1 - _kGyroTiltBlend) * grav_lpf
  //                          + _kGyroTiltBlend * gravity_from_gyro_integration
  // A value of 0.02 means 2 % gyro correction per sample @ ~100 Hz → ~2 s
  // time-constant for tilt correction without fighting the LPF.
  static const double _kGyroTiltBlend = 0.02;

  // Gyro fusion — more responsive alpha so fast turns reach the gate
  static const double _kGyroAlpha = 0.50;

  // ── Gravity state ────────────────────────────────────────────────────────────
  // Initialised to NaN so we can detect the very first sample and seed
  // directly — this eliminates the 2.5 s warmup spike entirely (FIX A).
  double _gravX = double.nan;
  double _gravY = double.nan;
  double _gravZ = double.nan;

  // Raw gyro (un-smoothed) for complementary tilt correction
  double _rawGyroX = 0.0;
  double _rawGyroY = 0.0;
  // _smoothedGyroZ used for turn gate (declared below)

  // UI smoothed axes (gravity-removed)
  double _uiLpfX = 0.0;
  double _uiLpfY = 0.0;
  double _uiLpfZ = 0.0;
  double _smoothedUiAcceleration = 0.0;

  // Minimum GPS speed (km/h) below which direction-reversal logic is skipped.
  static const double _kMinSpeedForReversalKmh = 3.0;

  // ── Hysteresis counts ────────────────────────────────────────────────────────
  static const int _kReversalHysteresisCount = 3;
  static const int _kAccelReentryCount       = 3;

  // ── GPS-speed derivative deceleration detector ───────────────────────────────
  // FIX C — replaces the unreliable IMU angle-based direction flag.
  // We compare the current GPS speed to the smoothed GPS speed from
  // _kGpsDecelWindowMs ago. If the vehicle is losing speed faster than
  // _kGpsDecelThresholdKmhPerS km/h per second, we are decelerating.
  static const double _kGpsDecelThresholdKmhPerS = 1.5; // ~0.42 m/s² — light braking
  static const int    _kGpsDecelWindowMs         = 800;  // look-back window
  // Hysteresis: GPS decel flag must be seen for this many GPS updates before commit
  static const int    _kGpsDecelConfirmSamples   = 1;
  // And must be gone for this many updates before releasing decel mode
  static const int    _kGpsAccelConfirmSamples   = 2;

  int _gpsDecelConfirmCount = 0;
  int _gpsAccelConfirmCount = 0;

  // ==================== STATE ====================
  bool _isTrackMode = false;
  final RacingTelemetryService _telemetryService = RacingTelemetryService();
  RacingTelemetryService get telemetry => _telemetryService;

  final TelemetryLogger _logger = TelemetryLogger();

  // ==================== ACCIDENT RISK ====================
  double    _currentRiskScore = 0;
  String    _currentRiskLevel = 'Low';
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

  bool _crashFeatureEnabled = false;

  final List<Map<String, dynamic>> _speedHistory = [];

  double    totalDistanceMeters = 0.0;
  Position? _lastPosition;
  bool      _isMonitoring = false;

  // ==================== JERK ====================
  final Queue<TimeStampedValue> _jerkBuffer = Queue();
  double?   _lastLinearMagnitude;
  DateTime? _lastAccelTimestamp;

  // Crash detection buffer — unsigned magnitude only
  final List<double> _rawAccelMagnitudes = [];

  // sustainedSampleCount = 3 → 1.5 s sustained harsh behaviour required
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

  // ==================== TURN DETECTION (GPS-primary) ====================
  final Queue<TimeStampedValue> _yawRateBuffer = Queue();

  double?   _lastGpsBearing;
  DateTime? _lastGpsBearingTimestamp;

  // Magnetometer-compass yaw (fallback when GPS speed < 15 km/h)
  double?   _lastYaw;
  DateTime? _lastYawTimestamp;

  DateTime? _turnStartTime;
  DateTime? _lastTurnDetection;
  double?   _turnEntrySpeed;
  double    _turnPeakYawRate = 0.0;

  // ==================== GYROSCOPE ====================
  double     _smoothedGyroZ      = 0.0;
  final bool _useGyroscopeFusion = true;

  // ==================== DIRECTION / DECELERATION STATE ====================
  // FIX C: _isDecelerating is now driven by GPS speed derivative, not IMU angles.
  // The IMU anchor fields are kept only for track-mode telemetry — they are no
  // longer used for the braking/accel classification in normal mode.
  bool _isDecelerating = false;

  // Legacy IMU anchor — retained for _detectDirectionReversalImu() which is
  // now only called in track mode (where GPS bearing is also available but
  // we keep the IMU path for high-frequency telemetry).
  double? _anchorLinX;
  double? _anchorLinY;
  double? _anchorLinZ;
  int     _reversalConfirmCount = 0;
  int     _accelReentryCount    = 0;

  // FIX C: settled-threshold is kept for the UI magnitude display only.
  final double magnitudeSettledThreshold  = 0.3; // lowered — pure vibration floor
  final double directionReversalThreshold = 150.0; // kept for track mode

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

    _jerkMultiplier = 1.0;
    _yawMultiplier  = 1.0;
    _uiLpfX = 0.0;
    _uiLpfY = 0.0;
    _uiLpfZ = 0.0;
    _smoothedUiAcceleration = 0.0;

    // FIX A: Reset gravity to NaN so the first real sample seeds it instantly.
    _gravX = double.nan;
    _gravY = double.nan;
    _gravZ = double.nan;
    _rawGyroX = 0.0;
    _rawGyroY = 0.0;

    // FIX C: Reset GPS decel detector
    _isDecelerating       = false;
    _gpsDecelConfirmCount = 0;
    _gpsAccelConfirmCount = 0;

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

    // Reset IMU anchor state
    _anchorLinX           = null;
    _anchorLinY           = null;
    _anchorLinZ           = null;
    _reversalConfirmCount = 0;
    _accelReentryCount    = 0;

    _lastGpsBearing          = null;
    _lastGpsBearingTimestamp = null;
    _lastYaw          = null;
    _lastYawTimestamp = null;

    _jerkBuffer.clear();
    _yawRateBuffer.clear();
    _lastLinearMagnitude = null;
    _lastAccelTimestamp  = null;
    _rawAccelMagnitudes.clear();
    _speedHistory.clear();

    _crashFeatureEnabled = ref.read(featureNotifierProvider) ?? false;
    ref.listenManual(featureNotifierProvider, (_, next) {
      _crashFeatureEnabled = next ?? false;
    });

    ref.read(vehicleMonitorProvider.notifier).setVehicle(vehicleId);
    ref.read(vehicleMonitorProvider.notifier).setMake(make);
    ref.read(vehicleMonitorProvider.notifier).setModel(model);

    sendNotification('RAXXY', _isTrackMode ? 'Track Mode Active' : 'Monitoring service started');
    debugPrint('RAXXY: Monitoring started. Track Mode: $_isTrackMode');

    _checkStressTriggers(userId);

    if (!_isTrackMode) {
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

    // ── UI / event timer (500 ms) ──────────────────────────────────────────
    _uiUpdateTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {

      if (!_isTrackMode) {
        _calculateAccidentRisk(ref);
      }

      if (!_isTrackMode) {
        if (_jerkBuffer.length >= 10 && currentSpeedKmh > _t.minSpeedThresholdKmh) {
          final double meanJerk =
              _jerkBuffer.map((e) => e.value).reduce((a, b) => a + b) /
                  _jerkBuffer.length;
          final double variance =
              _jerkBuffer.map((e) => pow(e.value - meanJerk, 2)).reduce((a, b) => a + b) /
                  _jerkBuffer.length;
          final double jerkStdDev = sqrt(variance);

          final double jerkThreshold = _t.jerkStdDevThreshold * _jerkMultiplier;

          if (jerkStdDev > jerkThreshold) {
            if (!_isDecelerating) {
              // ── HARSH ACCELERATION ──────────────────────────────────────
              _consecutiveHarshAccel++;
              _consecutiveHarshBrake = 0;
              _sessionService.updateAccelDecelState('accel');

              if (_consecutiveHarshAccel >= sustainedSampleCount &&
                  _shouldSendHaptic(_lastHarshAccelNotification)) {
                _sessionService.incrementHarshAccel();
                _lastHarshAccelNotification = DateTime.now();
                _coachingService.triggerFeedback(
                  message: 'Easy on the gas!',
                  vibrationPattern: [0, 200, 100, 200],
                );
                _feedbackService.evaluateAcceleration(jerkStdDev, currentSpeedKmh);
                debugPrint('🟢 Harsh ACCEL (JerkStdDev): ${jerkStdDev.toStringAsFixed(2)} m/s³');
                _consecutiveHarshAccel = 0;
              }
            } else {
              // ── HARSH BRAKING ───────────────────────────────────────────
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
                debugPrint('🔴 Harsh BRAKE (JerkStdDev): ${jerkStdDev.toStringAsFixed(2)} m/s³');
                _consecutiveHarshBrake = 0;
              }
            }
          } else {
            _consecutiveHarshAccel = 0;
            _consecutiveHarshBrake = 0;
            _sessionService.updateAccelDecelState('neutral');
          }

          if (_crashFeatureEnabled) {
            _checkCrashFromAcceleration(context, ref, jerkStdDev);
          }
        } else if (currentSpeedKmh <= _t.minSpeedThresholdKmh) {
          _consecutiveHarshAccel = 0;
          _consecutiveHarshBrake = 0;
        }

      } else {
        // Track Mode
        if (currentAcceleration != null) {
          _telemetryService.processTrackTelemetry(
            currentSpeed: currentSpeedKmh,
            accelX: currentAcceleration!.x,
            accelY: currentAcceleration!.y,
            gyroZ: _useGyroscopeFusion ? _smoothedGyroZ : 0.0,
          );
        }
      }

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

    // ── MAGNETOMETER ──────────────────────────────────────────────────────────
    _magSub = magnetometerEvents.listen((event) {
      _logger.logMagnetometer(event);
      currentMagnetometer = event;
    });

    // ── GYROSCOPE ─────────────────────────────────────────────────────────────
    if (_useGyroscopeFusion) {
      _gyroSub = gyroscopeEvents.listen((GyroscopeEvent event) {
        _logger.logGyroscope(event);
        _rawGyroX  = event.x;
        _rawGyroY  = event.y;
        _smoothedGyroZ =
            (_kGyroAlpha * event.z) + ((1 - _kGyroAlpha) * _smoothedGyroZ);
      });
      debugPrint('✅ Gyroscope fusion enabled');
    }

    // ── ACCELEROMETER ─────────────────────────────────────────────────────────
    _accelSub = userAccelerometerEvents.listen((event) {
      _logger.logAccelerometer(event);

      final DateTime now = DateTime.now();
      currentAcceleration = event;

      // ── FIX A: First-sample seeding ─────────────────────────────────────
      if (_gravX.isNaN) {
        _gravX = event.x;
        _gravY = event.y;
        _gravZ = event.z;
        // Seed UI LPF too so it starts at zero linear accel
        _uiLpfX = 0.0;
        _uiLpfY = 0.0;
        _uiLpfZ = 0.0;
        return; // Skip the rest for this single seed sample
      }

      // ── FIX A + B: Complementary gravity update ──────────────────────────
      double gx = _kGravityAlpha * _gravX + (1 - _kGravityAlpha) * event.x;
      double gy = _kGravityAlpha * _gravY + (1 - _kGravityAlpha) * event.y;
      double gz = _kGravityAlpha * _gravZ + (1 - _kGravityAlpha) * event.z;

      if (_useGyroscopeFusion) {
        if (_lastAccelTimestamp != null) {
          final double dt =
              now.difference(_lastAccelTimestamp!).inMicroseconds / 1e6;
          if (dt > 0.001 && dt < 0.1) {
            final double dGx = ( _rawGyroY * gz - 0            ) * dt;
            final double dGy = ( 0          * 0  - _rawGyroX * gz) * dt;
            final double dGz = ( _rawGyroX * gy  - _rawGyroY * gx) * dt;

            gx += _kGyroTiltBlend * dGx;
            gy += _kGyroTiltBlend * dGy;
            gz += _kGyroTiltBlend * dGz;
          }
        }
      }

      _gravX = gx;
      _gravY = gy;
      _gravZ = gz;

      // ── Gravity-removed linear acceleration ──────────────────────────────
      final double linX = event.x - _gravX;
      final double linY = event.y - _gravY;
      final double linZ = event.z - _gravZ;

      final double linearMagnitude =
      sqrt(linX * linX + linY * linY + linZ * linZ);

      // ── FIX C: _isDecelerating is set by GPS in the position stream. ─────
      if (_isTrackMode) {
        _detectDirectionReversalImu(linX, linY, linZ, linearMagnitude);
      }

      // ── UI smoothing (gravity-removed axes) ──────────────────────────────
      // MOVED ABOVE JERK CALCULATION SO WE CAN USE IT FOR PHYSICAL JERK
      _uiLpfX = (_kLpfAlphaUi * linX) + ((1 - _kLpfAlphaUi) * _uiLpfX);
      _uiLpfY = (_kLpfAlphaUi * linY) + ((1 - _kLpfAlphaUi) * _uiLpfY);
      _uiLpfZ = (_kLpfAlphaUi * linZ) + ((1 - _kLpfAlphaUi) * _uiLpfZ);

      final double uiMagnitude =
      sqrt(_uiLpfX * _uiLpfX + _uiLpfY * _uiLpfY + _uiLpfZ * _uiLpfZ);
      _smoothedUiAcceleration = _isDecelerating ? -uiMagnitude : uiMagnitude;

      // Crash detection buffer — unsigned
      _rawAccelMagnitudes.add(linearMagnitude);
      if (_rawAccelMagnitudes.length > 5) _rawAccelMagnitudes.removeAt(0);

      // ── Jerk calculation ─────────────────────────────────────────────────
      // PATCH: Use the vibration-smoothed UI acceleration to calculate physical jerk
      if (_lastLinearMagnitude != null && _lastAccelTimestamp != null) {
        final double dt =
            now.difference(_lastAccelTimestamp!).inMicroseconds / 1e6;
        if (dt > 0.01) {
          final double jerk =
              (_smoothedUiAcceleration - _lastLinearMagnitude!) / dt;
          _jerkBuffer.add(TimeStampedValue(now, jerk));
          _lastLinearMagnitude = _smoothedUiAcceleration;
          _lastAccelTimestamp  = now;
        }
      } else {
        _lastLinearMagnitude = _smoothedUiAcceleration;
        _lastAccelTimestamp  = now;
      }

      // Purge jerk older than 1 s
      while (_jerkBuffer.isNotEmpty &&
          now.difference(_jerkBuffer.first.time).inMilliseconds >= 1000) {
        _jerkBuffer.removeFirst();
      }

      // Compass yaw fallback (GPS speed < 15 km/h)
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

    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 1,
      ),
    ).listen((position) {
      _logger.logGps(position);

      if (position.accuracy > 50.0) {
        debugPrint('Ignoring poor GPS: ${position.accuracy}m');
        return;
      }

      final DateTime now = DateTime.now();
      currentSpeedKmh = position.speed * 3.6;

      // ── FIX C: GPS-speed deceleration detector ───────────────────────────
      if (!_isTrackMode) {
        _updateDecelStateFromGps(now);
      }

      // ── GPS bearing → yaw rate ────────────────────────────────────────────
      if (!_isTrackMode && currentSpeedKmh >= _kMinSpeedForReversalKmh) {
        final double gpsBearing = position.heading;
        if (_lastGpsBearing != null && _lastGpsBearingTimestamp != null) {
          final double dtSec =
              now.difference(_lastGpsBearingTimestamp!).inMilliseconds / 1000.0;
          if (dtSec > 0) {
            double dBearing = gpsBearing - _lastGpsBearing!;
            if (dBearing > 180)  dBearing -= 360;
            if (dBearing < -180) dBearing += 360;
            final double yawRateRad = (dBearing * pi / 180.0) / dtSec;
            _yawRateBuffer.add(TimeStampedValue(now, yawRateRad));
          }
        }
        _lastGpsBearing          = gpsBearing;
        _lastGpsBearingTimestamp = now;
      }

      while (_yawRateBuffer.isNotEmpty &&
          now.difference(_yawRateBuffer.first.time).inMilliseconds >= 1000) {
        _yawRateBuffer.removeFirst();
      }

      if (!_isTrackMode) {
        _detectTurn();
      }

      if (!_isTrackMode) {
        _speedHistory.add({'time': now, 'speed': currentSpeedKmh});
        if (_speedHistory.length > 20) _speedHistory.removeAt(0);

        if (_crashFeatureEnabled &&
            _speedHistory.length >= 2 &&
            position.accuracy < 15.0) {
          _checkCrashFromSpeedDrop(context, ref);
        }
      } else {
        _telemetryService.updateGpsPosition(
            position.latitude, position.longitude);
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

  // ============================================================================
  // FIX C: GPS-SPEED DECELERATION DETECTOR
  // ============================================================================
  void _updateDecelStateFromGps(DateTime now) {
    if (_speedHistory.length < 2) return;

    Map<String, dynamic>? referenceEntry;
    for (int i = 0; i < _speedHistory.length - 1; i++) {
      final DateTime sampleTime = _speedHistory[i]['time'] as DateTime;
      final int ageMs = now.difference(sampleTime).inMilliseconds;
      if (ageMs <= _kGpsDecelWindowMs) {
        referenceEntry = _speedHistory[i];
        break;
      }
    }
    referenceEntry ??= _speedHistory.first;

    final double refSpeed  = referenceEntry['speed'] as double;
    final DateTime refTime = referenceEntry['time'] as DateTime;
    final double dtSec     = now.difference(refTime).inMilliseconds / 1000.0;
    if (dtSec < 0.1) return;

    final double speedDerivKmhPerS = (currentSpeedKmh - refSpeed) / dtSec;

    if (!_isDecelerating) {
      if (speedDerivKmhPerS < -_kGpsDecelThresholdKmhPerS) {
        _gpsDecelConfirmCount++;
        _gpsAccelConfirmCount = 0;
        if (_gpsDecelConfirmCount >= _kGpsDecelConfirmSamples) {
          _isDecelerating       = true;
          _gpsDecelConfirmCount = 0;
          debugPrint(
            '🔴 GPS Decel confirmed: ${speedDerivKmhPerS.toStringAsFixed(1)} km/h/s',
          );
        }
      } else {
        _gpsDecelConfirmCount = 0;
      }
    } else {
      if (speedDerivKmhPerS >= -(_kGpsDecelThresholdKmhPerS * 0.5)) {
        _gpsAccelConfirmCount++;
        _gpsDecelConfirmCount = 0;
        if (_gpsAccelConfirmCount >= _kGpsAccelConfirmSamples) {
          _isDecelerating       = false;
          _gpsAccelConfirmCount = 0;
          debugPrint('🟢 GPS Accel confirmed — exiting DECEL mode');
        }
      } else {
        _gpsAccelConfirmCount = 0;
      }

      if (currentSpeedKmh < _kMinSpeedForReversalKmh) {
        _isDecelerating       = false;
        _gpsDecelConfirmCount = 0;
        _gpsAccelConfirmCount = 0;
      }
    }
  }

  // ============================================================================
  // IMU DIRECTION REVERSAL (TRACK MODE ONLY)
  // ============================================================================
  void _detectDirectionReversalImu(
      double linX,
      double linY,
      double linZ,
      double magnitude,
      ) {
    if (magnitude < magnitudeSettledThreshold) {
      _isDecelerating       = false;
      _reversalConfirmCount = 0;
      _accelReentryCount    = 0;
      _anchorLinX           = null;
      _anchorLinY           = null;
      _anchorLinZ           = null;
      return;
    }

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
      _anchorLinX = linX; _anchorLinY = linY; _anchorLinZ = linZ;
      return;
    }

    final double cosTheta = (
        (_anchorLinX! * linX + _anchorLinY! * linY + _anchorLinZ! * linZ) /
            (anchorMag * magnitude)
    ).clamp(-1.0, 1.0);
    final double angleDegrees = acos(cosTheta) * (180.0 / pi);

    if (!_isDecelerating) {
      if (angleDegrees > directionReversalThreshold) {
        _reversalConfirmCount++;
        _accelReentryCount = 0;
        if (_reversalConfirmCount >= _kReversalHysteresisCount) {
          _isDecelerating       = true;
          _reversalConfirmCount = 0;
          _anchorLinX = linX; _anchorLinY = linY; _anchorLinZ = linZ;
        }
      } else {
        _reversalConfirmCount = 0;
        _anchorLinX = linX; _anchorLinY = linY; _anchorLinZ = linZ;
      }
    } else {
      if (angleDegrees <= directionReversalThreshold) {
        _accelReentryCount++;
        if (_accelReentryCount >= _kAccelReentryCount) {
          _isDecelerating       = false;
          _accelReentryCount    = 0;
          _reversalConfirmCount = 0;
          _anchorLinX = linX; _anchorLinY = linY; _anchorLinZ = linZ;
        }
      } else {
        _accelReentryCount = 0;
        _anchorLinX = linX; _anchorLinY = linY; _anchorLinZ = linZ;
      }
    }
  }

  // ==================== FETCH PERSONALIZED THRESHOLDS ====================
  Future<void> _fetchDynamicThresholdModifiers(String userId) async {
    try {
      final profile = await DriverProfileService.getCachedProfile(userId);
      if (profile != null && profile['thresholdModifiers'] != null) {
        final mods = profile['thresholdModifiers'];
        _jerkMultiplier = (mods['jerkThresholdMultiplier'] ?? 1.0).toDouble();
        _yawMultiplier  = (mods['yawThresholdMultiplier']  ?? 1.0).toDouble();
        debugPrint(
          '🔧 Personalized Modifiers — Jerk: $_jerkMultiplier, Yaw: $_yawMultiplier',
        );
      }
    } catch (e) {
      debugPrint('Failed to load threshold modifiers: $e');
    }
  }

  // ==================== COMPASS YAW FALLBACK ====================
  void _calculateCompassYawFallback(
      UserAccelerometerEvent accel,
      MagnetometerEvent mag,
      DateTime now,
      ) {
    final double normA =
    sqrt(accel.x * accel.x + accel.y * accel.y + accel.z * accel.z);
    if (normA == 0) return;

    final double ax = accel.x / normA;
    final double ay = accel.y / normA;
    final double az = accel.z / normA;
    final double pitch = atan2(-ax, sqrt(ay * ay + az * az));
    final double roll  = atan2(ay, az);

    final double magXComp = mag.x * cos(pitch) +
        mag.y * sin(pitch) * sin(roll) +
        mag.z * sin(pitch) * cos(roll);
    final double magYComp = mag.y * cos(roll) - mag.z * sin(roll);
    final double yaw = atan2(-magYComp, magXComp);

    if (_lastYaw != null && _lastYawTimestamp != null) {
      final double dt =
          now.difference(_lastYawTimestamp!).inMicroseconds / 1e6;
      if (dt > 0) {
        double dYaw = yaw - _lastYaw!;
        if (dYaw > pi)  dYaw -= 2 * pi;
        if (dYaw < -pi) dYaw += 2 * pi;
        _yawRateBuffer.add(TimeStampedValue(now, dYaw / dt));
      }
    }
    _lastYaw          = yaw;
    _lastYawTimestamp = now;

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
      final int hour = DateTime.now().hour;
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
      _coachingService.triggerFeedback(message: body, vibrationPattern: [0, 200]);
      _hasWarnedAboutTimeTrigger = true;
      debugPrint('⚠️ Preventative Alert: $title');
    });
  }

  // ==================== TURN DETECTION ====================
  void _detectTurn() {
    if (_isTrackMode) return;
    if (_yawRateBuffer.isEmpty || currentSpeedKmh < _t.minSpeedThresholdKmh) {
      _resetTurnState();
      return;
    }

    final double meanYawRate =
        _yawRateBuffer.map((e) => e.value).reduce((a, b) => a + b) /
            _yawRateBuffer.length;

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
        if (_useGyroscopeFusion &&
            _smoothedGyroZ.abs() <= _t.gyroRotationThreshold) {
          debugPrint('⚠️ Turn rejected: no gyro rotation');
          _resetTurnState();
          return;
        }

        if (_lastTurnDetection != null &&
            DateTime.now().difference(_lastTurnDetection!) <
                Duration(seconds: _t.turnCooldownSeconds)) {
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
            _turnEntrySpeed ?? currentSpeedKmh, currentSpeedKmh, _turnPeakYawRate);
        _feedbackService.evaluateTurn(_turnPeakYawRate, currentSpeedKmh);

        debugPrint(
          '🔄 Turn: $direction | Peak: ${_turnPeakYawRate.toStringAsFixed(2)} rad/s | '
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

  // ==================== CRASH — ACCELERATION ====================
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

    final double accelFluctuation =
        _rawAccelMagnitudes[_rawAccelMagnitudes.length - 1] -
            _rawAccelMagnitudes[_rawAccelMagnitudes.length - 2];

    if (accelFluctuation.abs() > _t.crashAccelFluctuationLimit) {
      _triggerCrashDetection(context, ref);
    }
  }

  // ==================== CRASH — SPEED DROP ====================
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

  // ==================== STOP MONITORING ====================
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
          // 🛑 GUARDIAN SAFETY FEATURE (AUTO SMS)
          // =================================================================
          try {
            final userDoc =
            await firestore.collection('users').doc(_userId).get();
            if (userDoc.exists) {
              final age             = userDoc.data()?['age'];
              final guardianContact = userDoc.data()?['guardianContact'];

              if (age != null &&
                  age < 18 &&
                  guardianContact != null &&
                  guardianContact.toString().isNotEmpty) {
                final driverName =
                    userDoc.data()?['name'] ?? 'The driver';
                final dist   = (totalDistanceMeters / 1000).toStringAsFixed(1);
                final maxSpd = summary['maxSpeedKmh']?.toStringAsFixed(0) ?? '0';
                final hBrakes = summary['harshBrakes'] ?? 0;
                final hAccels = summary['harshAccelerations'] ?? 0;

                final String smsMessage =
                    "🛡️ RAXXY Guardian Alert:\n"
                    "$driverName has finished driving.\n"
                    "• Distance: $dist km\n"
                    "• Max Speed: $maxSpd km/h\n"
                    "• Harsh Brakes: $hBrakes\n"
                    "• Harsh Accels: $hAccels";

                try {
                  await sendSMS(
                    message: smsMessage,
                    recipients: [guardianContact],
                    sendDirect: true,
                  );
                  debugPrint('✅ Guardian SMS sent!');
                } catch (smsError) {
                  debugPrint('❌ Guardian SMS failed: $smsError');
                }
              }
            }
          } catch (e) {
            debugPrint('❌ Guardian check error: $e');
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

  // ==================== ACCIDENT RISK ====================
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
    _currentRiskLevel = risk <= 30 ? 'Low' : risk <= 60 ? 'Medium' : 'High';

    ref.read(vehicleMonitorProvider.notifier)
        .updateRisk(_currentRiskScore, _currentRiskLevel);

    if (_lastRiskAlert == null ||
        DateTime.now().difference(_lastRiskAlert!) > _kRiskCooldown) {
      _feedbackService.evaluateAccidentRisk(_currentRiskLevel, _currentRiskScore);
      _lastRiskAlert = DateTime.now();
    }
  }
}