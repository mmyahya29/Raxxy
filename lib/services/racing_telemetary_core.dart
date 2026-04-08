import 'dart:math';

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
// PHASE 2: EXTENDED KALMAN FILTER
// ==========================================
class ExtendedKalmanFilter {
  List<double> X = [0.0, 0.0, 0.0, 0.0]; // [x, y, v, theta]
  List<List<double>> P = List.generate(4, (_) => List.filled(4, 0.0));

  final List<List<double>> Q = [
    [0.1, 0, 0, 0],
    [0, 0.1, 0, 0],
    [0, 0, 0.5, 0],
    [0, 0, 0, 0.05]
  ];

  final List<List<double>> R = [
    [9.0, 0],
    [0, 9.0]
  ];

  ExtendedKalmanFilter() {
    for (int i = 0; i < 4; i++) P[i][i] = 1.0;
  }

  void predict(double dt, double a, double omega) {
    double x = X[0], y = X[1], v = X[2], theta = X[3];

    X[0] = x + (v * cos(theta) * dt) + (0.5 * a * cos(theta) * dt * dt);
    X[1] = y + (v * sin(theta) * dt) + (0.5 * a * sin(theta) * dt * dt);
    X[2] = v + (a * dt);
    X[3] = theta + (omega * dt);

    for (int i = 0; i < 4; i++) P[i][i] += Q[i][i];
  }

  void update(double xGps, double yGps) {
    double y_resX = xGps - X[0];
    double y_resY = yGps - X[1];

    double s00 = P[0][0] + R[0][0];
    double s01 = P[0][1] + R[0][1];
    double s10 = P[1][0] + R[1][0];
    double s11 = P[1][1] + R[1][1];

    double det = (s00 * s11) - (s01 * s10);
    if (det == 0) return;

    double invS00 = s11 / det, invS01 = -s01 / det;
    double invS10 = -s10 / det, invS11 = s00 / det;

    List<List<double>> K = List.generate(4, (_) => List.filled(2, 0.0));
    for (int i = 0; i < 4; i++) {
      K[i][0] = P[i][0] * invS00 + P[i][1] * invS10;
      K[i][1] = P[i][0] * invS01 + P[i][1] * invS11;
    }

    X[0] += (K[0][0] * y_resX) + (K[0][1] * y_resY);
    X[1] += (K[1][0] * y_resX) + (K[1][1] * y_resY);
    X[2] += (K[2][0] * y_resX) + (K[2][1] * y_resY);
    X[3] += (K[3][0] * y_resX) + (K[3][1] * y_resY);

    for (int i = 0; i < 4; i++) {
      double p0 = P[i][0], p1 = P[i][1];
      for (int j = 0; j < 4; j++) {
        P[i][j] -= (K[i][0] * p0 + K[i][1] * p1);
      }
    }
  }
}

// ==========================================
// PHASE 3: OPTIMAL LINE & CROSS-TRACK ERROR
// ==========================================
class TrackAnalyzer {
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

  static double calculateCrossTrackError(
      CartesianPoint vehiclePoint, CartesianPoint lineStart, CartesianPoint lineEnd) {
    double A = lineEnd.y - lineStart.y;
    double B = lineStart.x - lineEnd.x;
    double C = (lineEnd.x * lineStart.y) - (lineStart.x * lineEnd.y);

    double denominator = sqrt(A * A + B * B);
    if (denominator == 0) return 0.0;

    return (A * vehiclePoint.x + B * vehiclePoint.y + C).abs() / denominator;
  }
}