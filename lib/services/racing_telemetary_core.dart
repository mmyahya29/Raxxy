import 'dart:math';
import 'package:ml_linalg/matrix.dart';

// ==========================================
// DATA MODELS
// ==========================================
class GpsData {
  final double latitude;
  final double longitude;
  final double speed;
  final double heading;
  final int timestampMs;
  GpsData(this.latitude, this.longitude, this.speed, this.heading, this.timestampMs);
}

class ImuData {
  final double accelX; // Forward acceleration
  final double accelY; // Lateral acceleration
  final double gyroZ;  // Yaw rate (Omega)
  final int timestampMs;
  ImuData(this.accelX, this.accelY, this.gyroZ, this.timestampMs);
}

class CartesianPoint {
  final double x;
  final double y;
  CartesianPoint(this.x, this.y);

  Map<String, double> toMap() => {'x': x, 'y': y};
  factory CartesianPoint.fromMap(Map<String, dynamic> map) =>
      CartesianPoint((map['x'] as num).toDouble(), (map['y'] as num).toDouble());
}

// ==========================================
// PHASE 1: COORDINATE CONVERSION & MAPPING
// ==========================================
class CoordinateConverter {
  static const double R = 6371000.0; // Earth's radius in meters

  /// Converts GPS to local Cartesian (x, y) relative to an anchor point.
  static CartesianPoint latLonToCartesian(
      double lat, double lon, double anchorLat, double anchorLon) {
    double latRad = lat * pi / 180.0;
    double lonRad = lon * pi / 180.0;
    double anchorLatRad = anchorLat * pi / 180.0;
    double anchorLonRad = anchorLon * pi / 180.0;

    // Equirectangular approximation for local distances
    double x = R * (lonRad - anchorLonRad) * cos(anchorLatRad);
    double y = R * (latRad - anchorLatRad);

    return CartesianPoint(x, y);
  }
}

class TrackBoundarySmoother {
  /// Catmull-Rom Spline Interpolation for smoothing jagged 1Hz GPS walking boundaries
  static List<CartesianPoint> smoothBoundary(List<CartesianPoint> points, {int resolution = 10}) {
    if (points.length < 4) return points;

    List<CartesianPoint> smoothed = [];

    for (int i = 0; i < points.length - 1; i++) {
      CartesianPoint p0 = points[(i - 1).clamp(0, points.length - 1)];
      CartesianPoint p1 = points[i];
      CartesianPoint p2 = points[(i + 1).clamp(0, points.length - 1)];
      CartesianPoint p3 = points[(i + 2).clamp(0, points.length - 1)];

      for (int tStep = 0; tStep < resolution; tStep++) {
        double t = tStep / resolution;
        double t2 = t * t;
        double t3 = t2 * t;

        double x = 0.5 * ((2 * p1.x) +
            (-p0.x + p2.x) * t +
            (2 * p0.x - 5 * p1.x + 4 * p2.x - p3.x) * t2 +
            (-p0.x + 3 * p1.x - 3 * p2.x + p3.x) * t3);

        double y = 0.5 * ((2 * p1.y) +
            (-p0.y + p2.y) * t +
            (2 * p0.y - 5 * p1.y + 4 * p2.y - p3.y) * t2 +
            (-p0.y + 3 * p1.y - 3 * p2.y + p3.y) * t3);

        smoothed.add(CartesianPoint(x, y));
      }
    }
    return smoothed;
  }
}

// ==========================================
// PHASE 2: EXTENDED KALMAN FILTER (SENSOR FUSION)
// ==========================================
class ExtendedKalmanFilter {
  // State Vector: [x, y, v, theta]^T
  Matrix X = Matrix.fromList([
    [0.0],
    [0.0],
    [0.0],
    [0.0]
  ]);

  // Covariance Matrix P (4x4, initialized to Identity for initial uncertainty)
  Matrix P = Matrix.fromList([
    [1.0, 0.0, 0.0, 0.0],
    [0.0, 1.0, 0.0, 0.0],
    [0.0, 0.0, 1.0, 0.0],
    [0.0, 0.0, 0.0, 1.0]
  ]);

  // Observation Matrix H (We only observe x and y from GPS -> 2x4 matrix)
  final Matrix H = Matrix.fromList([
    [1.0, 0.0, 0.0, 0.0],
    [0.0, 1.0, 0.0, 0.0],
  ]);

  // Identity Matrix (4x4)
  final Matrix I = Matrix.fromList([
    [1.0, 0.0, 0.0, 0.0],
    [0.0, 1.0, 0.0, 0.0],
    [0.0, 0.0, 1.0, 0.0],
    [0.0, 0.0, 0.0, 1.0]
  ]);

  // Process Noise Covariance (Q) - Uncertainty in our IMU sensors
  final Matrix Q = Matrix.fromList([
    [0.1, 0.0, 0.0, 0.0],
    [0.0, 0.1, 0.0, 0.0],
    [0.0, 0.0, 0.5, 0.0], // Velocity noise variance
    [0.0, 0.0, 0.0, 0.05], // Yaw noise variance
  ]);

  // Measurement Noise Covariance (R) - Uncertainty in 1Hz GPS (~3m radius)
  final Matrix R = Matrix.fromList([
    [9.0, 0.0], // 3^2
    [0.0, 9.0]  // 3^2
  ]);

  /// Predict Step: Called at 100Hz with IMU data (Acceleration & Gyro)
  void predict(double dt, double a, double omega) {
    double x = X[0][0];
    double y = X[1][0];
    double v = X[2][0];
    double theta = X[3][0];

    // 1. Project the state ahead using physics equations
    X = Matrix.fromList([
      [x + (v * cos(theta) * dt) + (0.5 * a * cos(theta) * dt * dt)],
      [y + (v * sin(theta) * dt) + (0.5 * a * sin(theta) * dt * dt)],
      [v + (a * dt)],
      [theta + (omega * dt)]
    ]);

    // 2. Project the error covariance ahead
    P = P + Q;
  }

  /// Update Step: Called at 1Hz with GPS measurement updates
  void update(double xGps, double yGps) {
    // 1. Measurement Vector (Z)
    Matrix Z = Matrix.fromList([
      [xGps],
      [yGps]
    ]);

    // 2. Compute Innovation (Residual): y_res = Z - H * X
    Matrix y_res = Z - (H * X);

    // 3. Compute Innovation Covariance: S = H * P * H^T + R
    Matrix S = (H * P * H.transpose()) + R;

    // 4. Compute Kalman Gain: K = P * H^T * S^-1
    Matrix K = P * H.transpose() * S.inverse();

    // 5. Update State Estimate: X = X + K * y_res
    X = X + (K * y_res);

    // 6. Update Error Covariance: P = (I - K * H) * P
    P = (I - (K * H)) * P;
  }
}

// ==========================================
// PHASE 3: OPTIMAL LINE & CROSS-TRACK ERROR
// ==========================================
class TrackAnalyzer {

  /// Averages the smoothed left and right boundaries to create a geometric centerline
  static List<CartesianPoint> calculateCenterline(
      List<CartesianPoint> leftBound, List<CartesianPoint> rightBound) {
    List<CartesianPoint> centerline = [];
    int minLength = min(leftBound.length, rightBound.length);

    for (int i = 0; i < minLength; i++) {
      double cx = (leftBound[i].x + rightBound[i].x) / 2.0;
      double cy = (leftBound[i].y + rightBound[i].y) / 2.0;
      centerline.add(CartesianPoint(cx, cy));
    }
    return centerline;
  }

  /// Calculates shortest distance from the vehicle's fused point to the nearest ideal line segment
  static double calculateCrossTrackError(
      CartesianPoint vehiclePoint, CartesianPoint lineStart, CartesianPoint lineEnd) {

    // Line equation: Ax + By + C = 0
    double A = lineEnd.y - lineStart.y;
    double B = lineStart.x - lineEnd.x;
    double C = (lineEnd.x * lineStart.y) - (lineStart.x * lineEnd.y);

    double numerator = (A * vehiclePoint.x + B * vehiclePoint.y + C).abs();
    double denominator = sqrt(A * A + B * B);

    if (denominator == 0) return 0.0;

    // Distance d
    return numerator / denominator;
  }
}

// ==========================================
// TELEMETRY ROUTER & MANAGER
// ==========================================
class RacingTelemetryService {
  final ExtendedKalmanFilter _ekf = ExtendedKalmanFilter();

  // Anchor points for Cartesian conversion (First GPS point recorded)
  double? _anchorLat;
  double? _anchorLon;

  DateTime? _lastPredictTime;

  // Store the live path for rendering or saving
  final List<CartesianPoint> _fusedTrajectory = [];

  /// Called at 1Hz from the GPS Stream
  void updateGpsPosition(double latitude, double longitude) {
    // Set the anchor on the very first GPS ping of the session
    if (_anchorLat == null || _anchorLon == null) {
      _anchorLat = latitude;
      _anchorLon = longitude;
    }

    // Convert GPS to Cartesian plane relative to our anchor
    final cartesian = CoordinateConverter.latLonToCartesian(
        latitude, longitude, _anchorLat!, _anchorLon!
    );

    // Provide the ground-truth to the Kalman Filter to correct IMU drift
    _ekf.update(cartesian.x, cartesian.y);
  }

  /// Called at 100Hz from the UI/IMU timer
  void processTrackTelemetry({
    required double currentSpeed,
    required double accelX, // Forward Acceleration
    required double accelY, // Lateral Acceleration (used for friction circle, omitted in 2D EKF)
    required double gyroZ,  // Yaw Rate
  }) {
    final now = DateTime.now();

    if (_lastPredictTime != null) {
      final dt = now.difference(_lastPredictTime!).inMicroseconds / 1e6; // dt in seconds

      if (dt > 0) {
        // Step physics forward using IMU
        _ekf.predict(dt, accelX, gyroZ);

        // Record the fused point
        _fusedTrajectory.add(CartesianPoint(_ekf.X[0][0], _ekf.X[1][0]));
      }
    }
    _lastPredictTime = now;
  }

  /// Returns the completed session data
  Map<String, dynamic> getLapData() {
    return {
      'fused_trajectory': _fusedTrajectory.map((p) => p.toMap()).toList(),
      'final_state_x': _ekf.X[0][0],
      'final_state_y': _ekf.X[1][0],
      'final_velocity': _ekf.X[2][0],
      'final_heading': _ekf.X[3][0],
    };
  }

  /// Resets the engine for a new session
  void reset() {
    _anchorLat = null;
    _anchorLon = null;
    _lastPredictTime = null;
    _fusedTrajectory.clear();

    _ekf.X = Matrix.fromList([[0.0], [0.0], [0.0], [0.0]]);
    _ekf.P = Matrix.fromList([
      [1.0, 0.0, 0.0, 0.0],
      [0.0, 1.0, 0.0, 0.0],
      [0.0, 0.0, 1.0, 0.0],
      [0.0, 0.0, 0.0, 1.0]
    ]);
  }
}