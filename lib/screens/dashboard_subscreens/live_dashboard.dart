import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../../providers/provider.dart';
import '../../services/monitoring_service/vehicle_monitor_service.dart';

class LiveDrivingScreen extends ConsumerStatefulWidget {
  const LiveDrivingScreen({super.key});

  @override
  ConsumerState<LiveDrivingScreen> createState() => _LiveDrivingScreenState();
}

class _LiveDrivingScreenState extends ConsumerState<LiveDrivingScreen>
    with TickerProviderStateMixin {
  late AnimationController _gaugeAnimationController;
  late AnimationController _gForceAnimationController;
  late AnimationController _pulseController;
  late AnimationController _turnController;

  String _currentTurnDirection = "none";

  @override
  void initState() {
    super.initState();

    // Hide system UI for full immersion
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _gaugeAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _gForceAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _turnController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void dispose() {
    // Restore system UI
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );

    _gaugeAnimationController.dispose();
    _gForceAnimationController.dispose();
    _pulseController.dispose();
    _turnController.dispose();
    super.dispose();
  }

  Color _getHeatColor(double value, double maxValue) {
    double ratio = (value / maxValue).clamp(0.0, 1.0);

    if (ratio < 0.3) {
      return Color.lerp(const Color(0xFF00E5FF), const Color(0xFF2196F3), ratio / 0.3)!;
    } else if (ratio < 0.6) {
      return Color.lerp(const Color(0xFF2196F3), const Color(0xFF9C27B0), (ratio - 0.3) / 0.3)!;
    } else if (ratio < 0.8) {
      return Color.lerp(const Color(0xFF9C27B0), const Color(0xFFFF9800), (ratio - 0.6) / 0.2)!;
    } else {
      return Color.lerp(const Color(0xFFFF9800), const Color(0xFFFF5252), (ratio - 0.8) / 0.2)!;
    }
  }

  String _getRiskLevel(double speed, double gForce, double acceleration) {
    double riskScore = 0;

    if (speed > 120) riskScore += 30;
    else if (speed > 80) riskScore += 15;

    if (gForce.abs() > 2.0) riskScore += 40;
    else if (gForce.abs() > 1.0) riskScore += 20;

    if (acceleration.abs() > 3.0) riskScore += 30;
    else if (acceleration.abs() > 2.0) riskScore += 15;

    if (riskScore > 60) return "High";
    if (riskScore > 30) return "Medium";
    return "Low";
  }

  Color _getRiskColor(String risk) {
    switch (risk) {
      case "High":
        return const Color(0xFFFF5252);
      case "Medium":
        return const Color(0xFFFF9800);
      default:
        return const Color(0xFF4CAF50);
    }
  }

  void _detectTurn(double lateralX) {
    const double turnThreshold = 2.5;

    if (lateralX.abs() > turnThreshold) {
      String newDirection = lateralX > 0 ? "right" : "left";

      if (_currentTurnDirection != newDirection) {
        setState(() {
          _currentTurnDirection = newDirection;
        });
        _turnController.forward(from: 0);

        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _currentTurnDirection = "none";
            });
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final monitorState = ref.watch(vehicleMonitorProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    double currentSpeed = monitorState.speed;
    double currentAcceleration = monitorState.acceleration;
    double gForce = currentAcceleration / 9.8;

    UserAccelerometerEvent? accelEvent = VehicleMonitorService().currentAcceleration;
    double lateralX = accelEvent?.x ?? 0.0;
    double lateralY = accelEvent?.y ?? 0.0;

    _detectTurn(lateralX);

    String riskLevel = _getRiskLevel(currentSpeed, gForce, currentAcceleration);
    String vehicleName = monitorState.make != null && monitorState.model != null
        ? "${monitorState.make} ${monitorState.model}"
        : "RAXXY";

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0E27) : const Color(0xFF1A1F3A),
      body: Stack(
        children: [
          CustomPaint(
            size: Size(
              MediaQuery.of(context).size.width,
              MediaQuery.of(context).size.height,
            ),
            painter: GridBackgroundPainter(animation: _pulseController),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: Column(
                        children: [
                          _buildTopBar(context),
                          SizedBox(height: 15.h),
                          _buildSpeedGauge(currentSpeed),
                          SizedBox(height: 8.h),
                          Text(
                            vehicleName.toUpperCase(),
                            style: TextStyle(
                              color: const Color(0xFF8B7CFF),
                              fontSize: 14.sp,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                          SizedBox(height: 10.h),
                          if (currentSpeed > 100 || gForce.abs() > 1.5)
                            _buildWarningBanner("Check Tire Pressure"),
                          if (_currentTurnDirection != "none")
                            _buildTurnIndicator(_currentTurnDirection),
                          const Spacer(),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20.w),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildAccelerationGauge(currentAcceleration),
                                _buildGForceRadar(gForce, lateralX, lateralY),
                              ],
                            ),
                          ),
                          SizedBox(height: 15.h),
                          _buildRiskIndicator(riskLevel),
                          SizedBox(height: 20.h),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 15.w, vertical: 8.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: EdgeInsets.all(8.r),
              decoration: BoxDecoration(
                color: const Color(0xFF8B7CFF).withOpacity(0.2),
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(color: const Color(0xFF8B7CFF), width: 1.5),
              ),
              child: Icon(
                Icons.arrow_back,
                color: const Color(0xFF8B7CFF),
                size: 20.r,
              ),
            ),
          ),
          Icon(
            Icons.settings,
            color: const Color(0xFF8B7CFF).withOpacity(0.6),
            size: 22.r,
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedGauge(double speed) {
    Color speedColor = _getHeatColor(speed, 180);

    return SizedBox(
      width: 240.w,
      height: 240.h,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 240.w,
            height: 240.h,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: speedColor.withOpacity(0.3),
                  blurRadius: 30,
                  spreadRadius: 8,
                ),
              ],
            ),
          ),
          CustomPaint(
            size: Size(240.w, 240.h),
            painter: SpeedGaugePainter(
              speed: speed,
              maxSpeed: 200,
              color: speedColor,
              animation: _gaugeAnimationController,
            ),
          ),
          Container(
            width: 170.w,
            height: 170.h,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Color(0xFF1E2447), Color(0xFF0A0E27)],
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    speed.toInt().toString(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 52.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'KM/H',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13.sp,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningBanner(String message) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
      padding: EdgeInsets.all(10.r),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: Colors.orange, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20.r),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              'WARNING: $message',
              style: TextStyle(
                color: Colors.orange,
                fontSize: 11.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTurnIndicator(String direction) {
    return FadeTransition(
      opacity: _turnController,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 30.w, vertical: 8.h),
        padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 15.w),
        decoration: BoxDecoration(
          color: const Color(0xFF00E5FF).withOpacity(0.2),
          borderRadius: BorderRadius.circular(15.r),
          border: Border.all(color: const Color(0xFF00E5FF), width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (direction == "left") ...[
              Icon(Icons.arrow_back, color: const Color(0xFF00E5FF), size: 20.r),
              SizedBox(width: 8.w),
            ],
            Text(
              '${direction.toUpperCase()} TURN',
              style: TextStyle(
                color: const Color(0xFF00E5FF),
                fontSize: 11.sp,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            if (direction == "right") ...[
              SizedBox(width: 8.w),
              Icon(Icons.arrow_forward, color: const Color(0xFF00E5FF), size: 20.r),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAccelerationGauge(double acceleration) {
    Color accelColor = _getHeatColor(acceleration.abs(), 5);

    return SizedBox(
      width: 120.w,
      height: 120.h,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(120.w, 120.h),
            painter: MiniGaugePainter(
              value: acceleration.abs(),
              maxValue: 10,
              color: accelColor,
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                acceleration > 0 ? Icons.arrow_upward : Icons.arrow_downward,
                color: accelColor,
                size: 18.r,
              ),
              SizedBox(height: 3.h),
              Text(
                acceleration.abs().toStringAsFixed(1),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'm/s²',
                style: TextStyle(color: Colors.white70, fontSize: 10.sp),
              ),
              SizedBox(height: 3.h),
              Text(
                'ACCELERATION',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 8.sp,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGForceRadar(double gForce, double lateralX, double lateralY) {
    Color gColor = _getHeatColor(gForce.abs(), 3);

    return SizedBox(
      width: 130.w,
      height: 130.h,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(130.w, 130.h),
            painter: RadarPainter(animation: _gForceAnimationController),
          ),
          CustomPaint(
            size: Size(130.w, 130.h),
            painter: GForceDirectionPainter(
              lateralX: lateralX,
              lateralY: lateralY,
              color: gColor,
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                gForce.abs().toStringAsFixed(1),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'G',
                style: TextStyle(
                  color: gColor,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 3.h),
              Text(
                'G-FORCE',
                style: TextStyle(color: Colors.white70, fontSize: 9.sp),
              ),
              Text(
                'CURRENT G',
                style: TextStyle(color: Colors.white54, fontSize: 8.sp),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRiskIndicator(String riskLevel) {
    Color riskColor = _getRiskColor(riskLevel);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 30.w),
      padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 25.w),
      decoration: BoxDecoration(
        color: riskColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: riskColor, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            riskLevel == "High"
                ? Icons.error
                : riskLevel == "Medium"
                ? Icons.warning
                : Icons.check_circle,
            color: riskColor,
            size: 20.r,
          ),
          SizedBox(width: 8.w),
          Text(
            'RISK: $riskLevel',
            style: TextStyle(
              color: riskColor,
              fontSize: 13.sp,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// Keep all the CustomPainter classes (GridBackgroundPainter, SpeedGaugePainter, etc.)
// exactly as they were in the previous version

class GridBackgroundPainter extends CustomPainter {
  final Animation<double> animation;
  GridBackgroundPainter({required this.animation}) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF8B7CFF).withOpacity(0.1)
      ..strokeWidth = 1;

    double spacing = 40;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    final pulsePaint = Paint()
      ..color = const Color(0xFF8B7CFF).withOpacity(0.3 * animation.value)
      ..style = PaintingStyle.fill;

    for (double x = 0; x < size.width; x += spacing * 2) {
      for (double y = 0; y < size.height; y += spacing * 2) {
        canvas.drawCircle(Offset(x, y), 3 * animation.value, pulsePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class SpeedGaugePainter extends CustomPainter {
  final double speed;
  final double maxSpeed;
  final Color color;
  final Animation<double> animation;

  SpeedGaugePainter({
    required this.speed,
    required this.maxSpeed,
    required this.color,
    required this.animation,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final bgPaint = Paint()
      ..color = const Color(0xFF8B7CFF).withOpacity(0.1)
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 10),
      -pi * 0.75,
      pi * 1.5,
      false,
      bgPaint,
    );

    final speedPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          const Color(0xFF00E5FF),
          const Color(0xFF2196F3),
          const Color(0xFF9C27B0),
          color,
        ],
        startAngle: -pi * 0.75,
        endAngle: pi * 0.75,
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    double sweepAngle = (speed / maxSpeed).clamp(0.0, 1.0) * pi * 1.5;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 10),
      -pi * 0.75,
      sweepAngle,
      false,
      speedPaint,
    );

    final tickPaint = Paint()
      ..color = Colors.white30
      ..strokeWidth = 2;

    for (int i = 0; i <= 10; i++) {
      double angle = -pi * 0.75 + (pi * 1.5) * (i / 10);
      double startRadius = radius - 20;
      double endRadius = radius - 10;

      Offset start = Offset(
        center.dx + startRadius * cos(angle),
        center.dy + startRadius * sin(angle),
      );
      Offset end = Offset(
        center.dx + endRadius * cos(angle),
        center.dy + endRadius * sin(angle),
      );

      canvas.drawLine(start, end, tickPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class MiniGaugePainter extends CustomPainter {
  final double value;
  final double maxValue;
  final Color color;

  MiniGaugePainter({
    required this.value,
    required this.maxValue,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final bgPaint = Paint()
      ..color = const Color(0xFF8B7CFF).withOpacity(0.1)
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 8),
      -pi * 0.75,
      pi * 1.5,
      false,
      bgPaint,
    );

    final valuePaint = Paint()
      ..color = color
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    double sweepAngle = (value / maxValue).clamp(0.0, 1.0) * pi * 1.5;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 8),
      -pi * 0.75,
      sweepAngle,
      false,
      valuePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class RadarPainter extends CustomPainter {
  final Animation<double> animation;
  RadarPainter({required this.animation}) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    final circlePaint = Paint()
      ..color = const Color(0xFF8B7CFF).withOpacity(0.2)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    for (int i = 1; i <= 3; i++) {
      canvas.drawCircle(center, maxRadius * (i / 3), circlePaint);
    }

    final crossPaint = Paint()
      ..color = const Color(0xFF8B7CFF).withOpacity(0.3)
      ..strokeWidth = 1;

    canvas.drawLine(
      Offset(center.dx - maxRadius, center.dy),
      Offset(center.dx + maxRadius, center.dy),
      crossPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - maxRadius),
      Offset(center.dx, center.dy + maxRadius),
      crossPaint,
    );

    final sweepPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF00E5FF).withOpacity(0.6),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius))
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    double angle = animation.value * 2 * pi;
    Offset sweepEnd = Offset(
      center.dx + maxRadius * cos(angle),
      center.dy + maxRadius * sin(angle),
    );

    canvas.drawLine(center, sweepEnd, sweepPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class GForceDirectionPainter extends CustomPainter {
  final double lateralX;
  final double lateralY;
  final Color color;

  GForceDirectionPainter({
    required this.lateralX,
    required this.lateralY,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 3;

    double normalizedX = (lateralX / 10).clamp(-1.0, 1.0);
    double normalizedY = (lateralY / 10).clamp(-1.0, 1.0);

    Offset forcePoint = Offset(
      center.dx + normalizedX * maxRadius,
      center.dy + normalizedY * maxRadius,
    );

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawCircle(forcePoint, 6, paint);

    final linePaint = Paint()
      ..color = color.withOpacity(0.6)
      ..strokeWidth = 3;

    canvas.drawLine(center, forcePoint, linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}