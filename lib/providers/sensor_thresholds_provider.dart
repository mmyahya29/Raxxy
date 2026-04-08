import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ============================================================
// DEFAULT VALUES — matching the original hardcoded constants
// from vehicle_monitor_service.dart exactly
// ============================================================
class SensorThresholdDefaults {
  static const double minSpeedThresholdKmh        = 0.0;   // _kMinSpeedThresholdKmh
  static const double accelerationThreshold       = 1.8;   // _kAccelerationThreshold
  static const double jitterThreshold             = 2.0;   // _kJitterThreshold
  static const double turnForceThreshold          = 1.5;   // _kTurnForceThreshold
  static const int    turnDurationMs              = 500;   // _kTurnDurationMs
  static const double gyroRotationThreshold       = 0.3;   // _kGyroRotationThreshold
  static const double smoothTurnLimit             = 3.0;   // _kSmoothTurnLimit
  static const double jerkyTurnLimit              = 5.0;   // _kJerkyTurnLimit
  static const double significantSpeedDrop        = 12.0;  // _kSignificantSpeedDrop
  static const double crashAccelFluctuationLimit  = 1.0;   // _kCrashAccelFluctuationLimit
  static const double crashSpeedDropLimit         = 15.0;  // _kCrashSpeedDropLimit (positive; applied as negative)
  static const int    notificationCooldownSeconds = 3;     // _kNotificationCooldown
  static const int    turnCooldownSeconds         = 1;     // _kTurnCooldown
  static const int    crashCooldownSeconds        = 10;    // _kCrashCooldown

  // NEW SENSEFLEET THRESHOLDS
  static const double jerkStdDevThreshold         = 2.5;   // Jerk SD for longitudinal events (m/s³)
  static const double yawRateThreshold            = 0.5;   // Yaw Rate for lateral events (rad/s)
}

// ============================================================
// DATA CLASS
// ============================================================
class SensorThresholds {
  final double minSpeedThresholdKmh;
  final double accelerationThreshold;
  final double jitterThreshold;
  final double turnForceThreshold;
  final int    turnDurationMs;
  final double gyroRotationThreshold;
  final double smoothTurnLimit;
  final double jerkyTurnLimit;
  final double significantSpeedDrop;
  final double crashAccelFluctuationLimit;
  final double crashSpeedDropLimit;
  final int    notificationCooldownSeconds;
  final int    turnCooldownSeconds;
  final int    crashCooldownSeconds;

  final double jerkStdDevThreshold;
  final double yawRateThreshold;

  const SensorThresholds({
    this.minSpeedThresholdKmh        = SensorThresholdDefaults.minSpeedThresholdKmh,
    this.accelerationThreshold       = SensorThresholdDefaults.accelerationThreshold,
    this.jitterThreshold             = SensorThresholdDefaults.jitterThreshold,
    this.turnForceThreshold          = SensorThresholdDefaults.turnForceThreshold,
    this.turnDurationMs              = SensorThresholdDefaults.turnDurationMs,
    this.gyroRotationThreshold       = SensorThresholdDefaults.gyroRotationThreshold,
    this.smoothTurnLimit             = SensorThresholdDefaults.smoothTurnLimit,
    this.jerkyTurnLimit              = SensorThresholdDefaults.jerkyTurnLimit,
    this.significantSpeedDrop        = SensorThresholdDefaults.significantSpeedDrop,
    this.crashAccelFluctuationLimit  = SensorThresholdDefaults.crashAccelFluctuationLimit,
    this.crashSpeedDropLimit         = SensorThresholdDefaults.crashSpeedDropLimit,
    this.notificationCooldownSeconds = SensorThresholdDefaults.notificationCooldownSeconds,
    this.turnCooldownSeconds         = SensorThresholdDefaults.turnCooldownSeconds,
    this.crashCooldownSeconds        = SensorThresholdDefaults.crashCooldownSeconds,
    this.jerkStdDevThreshold         = SensorThresholdDefaults.jerkStdDevThreshold,
    this.yawRateThreshold            = SensorThresholdDefaults.yawRateThreshold,
  });

  SensorThresholds copyWith({
    double? minSpeedThresholdKmh,
    double? accelerationThreshold,
    double? jitterThreshold,
    double? turnForceThreshold,
    int?    turnDurationMs,
    double? gyroRotationThreshold,
    double? smoothTurnLimit,
    double? jerkyTurnLimit,
    double? significantSpeedDrop,
    double? crashAccelFluctuationLimit,
    double? crashSpeedDropLimit,
    int?    notificationCooldownSeconds,
    int?    turnCooldownSeconds,
    int?    crashCooldownSeconds,
    double? jerkStdDevThreshold,
    double? yawRateThreshold,
  }) {
    return SensorThresholds(
      minSpeedThresholdKmh:        minSpeedThresholdKmh        ?? this.minSpeedThresholdKmh,
      accelerationThreshold:       accelerationThreshold       ?? this.accelerationThreshold,
      jitterThreshold:             jitterThreshold             ?? this.jitterThreshold,
      turnForceThreshold:          turnForceThreshold          ?? this.turnForceThreshold,
      turnDurationMs:              turnDurationMs              ?? this.turnDurationMs,
      gyroRotationThreshold:       gyroRotationThreshold       ?? this.gyroRotationThreshold,
      smoothTurnLimit:             smoothTurnLimit             ?? this.smoothTurnLimit,
      jerkyTurnLimit:              jerkyTurnLimit              ?? this.jerkyTurnLimit,
      significantSpeedDrop:        significantSpeedDrop        ?? this.significantSpeedDrop,
      crashAccelFluctuationLimit:  crashAccelFluctuationLimit  ?? this.crashAccelFluctuationLimit,
      crashSpeedDropLimit:         crashSpeedDropLimit         ?? this.crashSpeedDropLimit,
      notificationCooldownSeconds: notificationCooldownSeconds ?? this.notificationCooldownSeconds,
      turnCooldownSeconds:         turnCooldownSeconds         ?? this.turnCooldownSeconds,
      crashCooldownSeconds:        crashCooldownSeconds        ?? this.crashCooldownSeconds,
      jerkStdDevThreshold:         jerkStdDevThreshold         ?? this.jerkStdDevThreshold,
      yawRateThreshold:            yawRateThreshold            ?? this.yawRateThreshold,
    );
  }
}

// ============================================================
// NOTIFIER
// ============================================================
class SensorThresholdsNotifier extends StateNotifier<SensorThresholds> {
  SensorThresholdsNotifier() : super(const SensorThresholds()) {
    _load();
  }

  // SharedPreferences keys
  static const _kMinSpeed       = 'thresh_min_speed';
  static const _kAccel          = 'thresh_accel';
  static const _kJitter         = 'thresh_jitter';
  static const _kTurnForce      = 'thresh_turn_force';
  static const _kTurnDuration   = 'thresh_turn_duration';
  static const _kGyro           = 'thresh_gyro';
  static const _kSmoothTurn     = 'thresh_smooth_turn';
  static const _kJerkyTurn      = 'thresh_jerky_turn';
  static const _kSpeedDrop      = 'thresh_speed_drop';
  static const _kCrashAccel     = 'thresh_crash_accel';
  static const _kCrashSpeed     = 'thresh_crash_speed';
  static const _kNotifCooldown  = 'thresh_notif_cooldown';
  static const _kTurnCooldown   = 'thresh_turn_cooldown';
  static const _kCrashCooldown  = 'thresh_crash_cooldown';

  // New keys
  static const _kJerkStdDev     = 'thresh_jerk_std_dev';
  static const _kYawRate        = 'thresh_yaw_rate';

  /// Load persisted values, falling back to defaults from [SensorThresholdDefaults]
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = SensorThresholds(
      minSpeedThresholdKmh:        prefs.getDouble(_kMinSpeed)       ?? SensorThresholdDefaults.minSpeedThresholdKmh,
      accelerationThreshold:       prefs.getDouble(_kAccel)          ?? SensorThresholdDefaults.accelerationThreshold,
      jitterThreshold:             prefs.getDouble(_kJitter)         ?? SensorThresholdDefaults.jitterThreshold,
      turnForceThreshold:          prefs.getDouble(_kTurnForce)      ?? SensorThresholdDefaults.turnForceThreshold,
      turnDurationMs:              prefs.getInt(_kTurnDuration)      ?? SensorThresholdDefaults.turnDurationMs,
      gyroRotationThreshold:       prefs.getDouble(_kGyro)           ?? SensorThresholdDefaults.gyroRotationThreshold,
      smoothTurnLimit:             prefs.getDouble(_kSmoothTurn)     ?? SensorThresholdDefaults.smoothTurnLimit,
      jerkyTurnLimit:              prefs.getDouble(_kJerkyTurn)      ?? SensorThresholdDefaults.jerkyTurnLimit,
      significantSpeedDrop:        prefs.getDouble(_kSpeedDrop)      ?? SensorThresholdDefaults.significantSpeedDrop,
      crashAccelFluctuationLimit:  prefs.getDouble(_kCrashAccel)     ?? SensorThresholdDefaults.crashAccelFluctuationLimit,
      crashSpeedDropLimit:         prefs.getDouble(_kCrashSpeed)     ?? SensorThresholdDefaults.crashSpeedDropLimit,
      notificationCooldownSeconds: prefs.getInt(_kNotifCooldown)     ?? SensorThresholdDefaults.notificationCooldownSeconds,
      turnCooldownSeconds:         prefs.getInt(_kTurnCooldown)      ?? SensorThresholdDefaults.turnCooldownSeconds,
      crashCooldownSeconds:        prefs.getInt(_kCrashCooldown)     ?? SensorThresholdDefaults.crashCooldownSeconds,
      jerkStdDevThreshold:         prefs.getDouble(_kJerkStdDev)     ?? SensorThresholdDefaults.jerkStdDevThreshold,
      yawRateThreshold:            prefs.getDouble(_kYawRate)        ?? SensorThresholdDefaults.yawRateThreshold,
    );
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kMinSpeed,      state.minSpeedThresholdKmh);
    await prefs.setDouble(_kAccel,         state.accelerationThreshold);
    await prefs.setDouble(_kJitter,        state.jitterThreshold);
    await prefs.setDouble(_kTurnForce,     state.turnForceThreshold);
    await prefs.setInt   (_kTurnDuration,  state.turnDurationMs);
    await prefs.setDouble(_kGyro,          state.gyroRotationThreshold);
    await prefs.setDouble(_kSmoothTurn,    state.smoothTurnLimit);
    await prefs.setDouble(_kJerkyTurn,     state.jerkyTurnLimit);
    await prefs.setDouble(_kSpeedDrop,     state.significantSpeedDrop);
    await prefs.setDouble(_kCrashAccel,    state.crashAccelFluctuationLimit);
    await prefs.setDouble(_kCrashSpeed,    state.crashSpeedDropLimit);
    await prefs.setInt   (_kNotifCooldown, state.notificationCooldownSeconds);
    await prefs.setInt   (_kTurnCooldown,  state.turnCooldownSeconds);
    await prefs.setInt   (_kCrashCooldown, state.crashCooldownSeconds);

    // Persist new thresholds
    await prefs.setDouble(_kJerkStdDev,    state.jerkStdDevThreshold);
    await prefs.setDouble(_kYawRate,       state.yawRateThreshold);
  }

  /// Update thresholds and persist to SharedPreferences
  Future<void> update(SensorThresholds updated) async {
    state = updated;
    await _persist();
  }

  /// Reset all thresholds to the original hardcoded defaults
  Future<void> reset() async {
    state = const SensorThresholds(); // constructor defaults = SensorThresholdDefaults values
    await _persist();
  }
}

// ============================================================
// PROVIDER
// ============================================================
final sensorThresholdsProvider =
StateNotifierProvider<SensorThresholdsNotifier, SensorThresholds>(
      (ref) => SensorThresholdsNotifier(),
);