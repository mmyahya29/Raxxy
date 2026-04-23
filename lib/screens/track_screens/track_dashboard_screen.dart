import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../providers/provider.dart';
import '../../services/monitoring_service/vehicle_monitor_service.dart';

class RacingDashboardScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> trackData;
  const RacingDashboardScreen({super.key, required this.trackData});

  @override
  ConsumerState<RacingDashboardScreen> createState() => _RacingDashboardScreenState();
}

class _RacingDashboardScreenState extends ConsumerState<RacingDashboardScreen> with SingleTickerProviderStateMixin {
  Timer? _uiRefreshTimer;
  Map<String, dynamic> _liveData = {};
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = ref.read(firebaseAuthProvider);
      await VehicleMonitorService().startMonitoring(
        context: context,
        userId: auth.currentUser?.uid ?? '',
        vehicleId: 'track_vehicle',
        make: 'Track',
        model: 'Car',
        ref: ref,
        trackMode: true,
      );

      _uiRefreshTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
        if (mounted) {
          setState(() {
            _liveData = VehicleMonitorService().telemetry.getLapData();
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _uiRefreshTimer?.cancel();
    VehicleMonitorService().stopMonitoring(ref);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trackName = (widget.trackData['trackName'] ?? 'TRACK').toString().toUpperCase();

    final double speedKmh = VehicleMonitorService().currentSpeedKmh;
    final accel = VehicleMonitorService().currentAcceleration;

    final double gForceLat = accel != null ? (accel.x / 9.81) : 0.0;
    final double gForceLon = accel != null ? (accel.y / 9.81) : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFF050714),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 80.h),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      FadeTransition(
                        opacity: _pulseController,
                        child: Container(
                          width: 10.r, height: 10.r,
                          decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.redAccent, blurRadius: 10)]),
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Text('TELEMETRY LIVE', style: TextStyle(color: Colors.redAccent, fontSize: 12.sp, fontWeight: FontWeight.w900, letterSpacing: 2)),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: Colors.white54, size: 28.r),
                    onPressed: () => Navigator.pop(context),
                  )
                ],
              ),
              SizedBox(height: 5.h),
              Text(trackName, style: TextStyle(color: Colors.white, fontSize: 24.sp, fontWeight: FontWeight.w900, letterSpacing: 1.5)),

              SizedBox(height: 20.h),

              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A0E27),
                    borderRadius: BorderRadius.circular(30.r),
                    border: Border.all(color: const Color(0xFF8B7CFF).withOpacity(0.3), width: 2),
                    boxShadow: [BoxShadow(color: const Color(0xFF8B7CFF).withOpacity(0.1), blurRadius: 30)],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30.r),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Opacity(
                            opacity: 0.05,
                            child: GridPaper(color: const Color(0xFF00E5FF), interval: 50.w, subdivisions: 1),
                          ),
                        ),
                        CustomPaint(
                          painter: RacingRadarPainter(
                            trackData: widget.trackData,
                            carX: _liveData['final_state_x'] ?? 0.0,
                            carY: _liveData['final_state_y'] ?? 0.0,
                            heading: _liveData['final_heading'] ?? 0.0,
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              SizedBox(height: 20.h),

              Row(
                children: [
                  Expanded(child: _buildMetricCard('SPEED', speedKmh.toStringAsFixed(0), 'KM/H', const Color(0xFF00E5FF))),
                  SizedBox(width: 10.w),
                  Expanded(child: _buildMetricCard('LATERAL G', gForceLat.abs().toStringAsFixed(2), gForceLat > 0 ? 'R' : 'L', const Color(0xFFFF9800))),
                  SizedBox(width: 10.w),
                  Expanded(child: _buildMetricCard('LONG G', gForceLon.abs().toStringAsFixed(2), gForceLon > 0 ? 'ACCEL' : 'BRAKE', const Color(0xFF8B7CFF))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, String unit, Color accent) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 15.h),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F3A),
        borderRadius: BorderRadius.circular(15.r),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Text(title, style: TextStyle(color: Colors.white54, fontSize: 9.sp, fontWeight: FontWeight.bold, letterSpacing: 1)),
          SizedBox(height: 5.h),
          Text(value, style: TextStyle(color: Colors.white, fontSize: 22.sp, fontWeight: FontWeight.w900)),
          Text(unit, style: TextStyle(color: accent, fontSize: 10.sp, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class RacingRadarPainter extends CustomPainter {
  final Map<String, dynamic> trackData;
  final double carX;
  final double carY;
  final double heading;

  RacingRadarPainter({required this.trackData, required this.carX, required this.carY, required this.heading});

  @override
  void paint(Canvas canvas, Size size) {
    final leftData = trackData['leftBoundary'] as List<dynamic>? ?? [];
    final rightData = trackData['rightBoundary'] as List<dynamic>? ?? [];
    final centerData = trackData['centerline'] as List<dynamic>? ?? [];

    if (leftData.isEmpty && rightData.isEmpty) return;

    double minX = double.infinity, maxX = -double.infinity;
    double minY = double.infinity, maxY = -double.infinity;

    void updateBounds(Map<String, dynamic> p) {
      if (p['x'] < minX) minX = p['x'];
      if (p['x'] > maxX) maxX = p['x'];
      if (p['y'] < minY) minY = p['y'];
      if (p['y'] > maxY) maxY = p['y'];
    }

    for (var p in leftData) { updateBounds(p); }
    for (var p in rightData) { updateBounds(p); }

    double widthRange = (maxX - minX);
    double heightRange = (maxY - minY);
    if (widthRange == 0) widthRange = 1;
    if (heightRange == 0) heightRange = 1;

    minX -= widthRange * 0.1; maxX += widthRange * 0.1;
    minY -= heightRange * 0.1; maxY += heightRange * 0.1;
    widthRange = maxX - minX; heightRange = maxY - minY;

    double scaleX = size.width / widthRange;
    double scaleY = size.height / heightRange;
    double scale = min(scaleX, scaleY);

    double offsetX = (size.width - (widthRange * scale)) / 2;
    double offsetY = (size.height - (heightRange * scale)) / 2;

    Offset getOffset(double x, double y) {
      double scaledX = (x - minX) * scale + offsetX;
      double scaledY = size.height - ((y - minY) * scale + offsetY);
      return Offset(scaledX, scaledY);
    }

    void drawLine(List<dynamic> points, Color color, double width, {bool dashed = false}) {
      if (points.isEmpty) return;
      final paint = Paint()..color = color..strokeWidth = width..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;

      final path = Path();
      path.moveTo(getOffset(points[0]['x'], points[0]['y']).dx, getOffset(points[0]['x'], points[0]['y']).dy);
      for (int i = 1; i < points.length; i++) {
        path.lineTo(getOffset(points[i]['x'], points[i]['y']).dx, getOffset(points[i]['x'], points[i]['y']).dy);
      }

      if (dashed) {
        canvas.drawPath(path, paint..color = color.withOpacity(0.3));
      } else {
        canvas.drawPath(path, paint);
      }
    }

    drawLine(leftData, const Color(0xFF00E5FF), 3.0);
    drawLine(rightData, const Color(0xFFFF9800), 3.0);
    drawLine(centerData, Colors.white54, 1.5, dashed: true);

    final carOffset = getOffset(carX, carY);

    canvas.save();
    canvas.translate(carOffset.dx, carOffset.dy);
    canvas.rotate(-heading);

    final carPaint = Paint()..color = Colors.redAccent..style = PaintingStyle.fill;
    final carPath = Path()
      ..moveTo(0, -10)
      ..lineTo(7, 8)
      ..lineTo(0, 4)
      ..lineTo(-7, 8)
      ..close();

    canvas.drawShadow(carPath, Colors.redAccent, 10, true);
    canvas.drawPath(carPath, carPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant RacingRadarPainter oldDelegate) {
    return carX != oldDelegate.carX || carY != oldDelegate.carY || heading != oldDelegate.heading;
  }
}