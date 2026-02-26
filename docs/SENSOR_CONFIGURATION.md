# Sensor Configuration Reference

All sensor thresholds for Raxxy are defined at the top of
`lib/services/monitoring_service/vehicle_monitor_service.dart` (lines 20–88).
Changing these constants lets you tune detection sensitivity without touching
the underlying algorithm.

---

## General Thresholds

### `_kMinSpeedThresholdKmh` (default `0.0`)
The minimum GPS speed (km/h) before any driving event (acceleration, braking,
turning) can be triggered.

| Environment | Recommended value |
|---|---|
| Testing / development | `0.0` – events fire even when stationary |
| Production | `10.0` – ignore slow crawling in traffic |

---

## Acceleration & Braking

### `_kAccelerationThreshold` (default `1.8 m/s²`)
The longitudinal G-force required to register a **Harsh Acceleration** or
**Harsh Braking** event. 1 G ≈ 9.8 m/s², so 1.8 m/s² ≈ 0.18 G (mild).

| Environment | Recommended value |
|---|---|
| Testing | `1.8` – easy to trigger |
| Production | `2.5 – 3.0` – only genuine hard events |

### `_kJitterThreshold` (default `2.0`)
Noise filter applied to raw accelerometer data.  Readings whose magnitude
changes by less than this value between samples are discarded as sensor jitter.
Increase to filter more aggressively on noisy devices; decrease for higher
sensitivity.

---

## Turn Detection

### `_kTurnForceThreshold` (default `1.5 m/s²`)
Minimum lateral (sideways) force needed to begin counting a turn.

| Environment | Recommended value |
|---|---|
| Testing | `1.5` – detects gentle curves |
| Production | `2.0` – filters out mild lane changes |

### `_kTurnDurationMs` (default `500 ms`)
The lateral force must persist for at least this many milliseconds for the
event to be classified as a **turn** rather than a brief lane adjustment.

| Environment | Recommended value |
|---|---|
| Testing | `500` |
| Production | `700` |

### `_kLpfAlpha` (default `0.15`)
Low-pass filter smoothing coefficient applied to lateral force.
- `0.0` – fully smoothed (very slow response)
- `1.0` – raw unfiltered data

### `_kGyroRotationThreshold` (default `0.3 rad/s`)
Minimum gyroscope rotation rate used to *confirm* a detected turn.  If the
gyroscope reading is below this value during a suspected turn, the event is
discarded as a false positive.

| Environment | Recommended value |
|---|---|
| Testing | `0.3` |
| Production | `0.5` |

---

## Turn Quality Scoring

### `_kSmoothTurnLimit` (default `3.0 m/s²`)
Turns whose peak lateral force stays **below** this value are classified as
**Smooth**.

### `_kJerkyTurnLimit` (default `5.0 m/s²`)
Turns whose peak lateral force exceeds this value are classified as **Jerky**.
Values in between are classified as **Normal**.

### `_kSignificantSpeedDrop` (default `12.0 km/h`)
If the vehicle speed drops by more than this amount during a turn, the turn
quality is downgraded to **Jerky** regardless of lateral force.

---

## Crash Detection

### `_kCrashAccelFluctuationLimit` (default `1.0`)
The sudden change in acceleration magnitude (jerk) that raises a crash
suspicion flag.  Lower values make crash detection more sensitive but increase
false positives.

### `_kCrashSpeedDropLimit` (default `-15.0 km/h`)
If GPS speed drops by more than this amount within ~1.5 seconds while a high
jerk is also detected, a crash event is triggered and the emergency flow
begins.

---

## Cooldown Timers

Cooldown timers prevent the same event from firing repeatedly in quick
succession.

| Constant | Default | Purpose |
|---|---|---|
| `_kNotificationCooldown` | 3 s | Minimum gap between harsh-event push notifications |
| `_kTurnCooldown` | 1 s | Minimum gap between two separate turn events |
| `_kCrashCooldown` | 10 s | Minimum gap between crash triggers |
| `_kRiskCooldown` | 8 s | Minimum gap between accident-risk-score alerts |

---

## Production vs Testing Checklist

Before releasing to production, review these settings:

- [ ] `_kMinSpeedThresholdKmh` → raise to `10.0`
- [ ] `_kAccelerationThreshold` → raise to `2.5`–`3.0`
- [ ] `_kTurnForceThreshold` → raise to `2.0`
- [ ] `_kTurnDurationMs` → raise to `700`
- [ ] `_kGyroRotationThreshold` → raise to `0.5`
- [ ] `_kNotificationCooldown` → raise to `5` s
- [ ] `_kTurnCooldown` → raise to `2` s
