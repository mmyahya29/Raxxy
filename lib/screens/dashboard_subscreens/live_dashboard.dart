import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../../providers/provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/monitoring_service/vehicle_monitor_service.dart';

class LiveDrivingScreen extends ConsumerStatefulWidget {
  const LiveDrivingScreen({super.key});

  @override
  ConsumerState<LiveDrivingScreen> createState() => _LiveDrivingScreenState();
}

class _LiveDrivingScreenState extends ConsumerState<LiveDrivingScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _radarController;

  String _currentTurnDirection = "none";

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);

    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    _pulseController.dispose();
    _radarController.dispose();
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
      case "High": return const Color(0xFFFF5252);
      case "Medium": return const Color(0xFFFF9800);
      default: return const Color(0xFF4CAF50);
    }
  }

  void _detectTurn(double lateralX) {
    const double turnThreshold = 2.5;
    if (lateralX.abs() > turnThreshold) {
      String newDirection = lateralX > 0 ? "right" : "left";
      if (_currentTurnDirection != newDirection) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _currentTurnDirection = newDirection);
        });
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && _currentTurnDirection == newDirection) {
            setState(() => _currentTurnDirection = "none");
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final monitorState = ref.watch(vehicleMonitorProvider);
    final themeMode = ref.watch(themeNotifierProvider);
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);

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
        : "RAXXY SYSTEM";

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0E27) : const Color(0xFFF4F5F9),
      body: Padding(
        padding: EdgeInsets.only(bottom: 70.r),
        child: Stack(
          children: [
            // Animated Background
            Positioned.fill(
              child: CustomPaint(
                painter: GridBackgroundPainter(animation: _pulseController),
              ),
            ),

            SafeArea(
              child: Column(
                children: [
                  _buildTopBar(context),
                  SizedBox(height: 10.h),

                  // Vehicle Name
                  Text(
                    vehicleName.toUpperCase(),
                    style: TextStyle(
                      color: const Color(0xFF8B7CFF),
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 4,
                    ),
                  ),
                  SizedBox(height: 20.h),

                  // Main Speedometer Area (Flexible to take up center space)
                  Expanded(
                    flex: 5,
                    child: Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          _buildSmoothSpeedometer(currentSpeed, isDark),

                          // Floating Turn Indicator (Centered inside or above gauge)
                          Positioned(
                            top: 0,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 400),
                              transitionBuilder: (child, animation) => FadeTransition(
                                opacity: animation,
                                child: ScaleTransition(scale: animation, child: child),
                              ),
                              child: _currentTurnDirection != "none"
                                  ? _buildTurnIndicator(_currentTurnDirection)
                                  : const SizedBox.shrink(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Warning Banner area (takes up space only when needed)
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: (currentSpeed > 100 || gForce.abs() > 1.5)
                        ? _buildWarningBanner("Check Tire Pressure")
                        : const SizedBox.shrink(),
                  ),

                  // Bottom Metrics Area
                  Expanded(
                    flex: 3,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 25.w),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _buildSmoothAcceleration(currentAcceleration, isDark),
                          _buildSmoothGForceRadar(gForce, lateralX, lateralY, isDark),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 20.h),
                  _buildRiskIndicator(riskLevel),
                  SizedBox(height: 30.h),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- Smooth Animated Widgets using TweenAnimationBuilder ----

  Widget _buildSmoothSpeedometer(double targetSpeed, bool isDark) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: targetSpeed),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (context, speedValue, child) {
        Color speedColor = _getHeatColor(speedValue, 180);
        return SizedBox(
          width: 280.w,
          height: 280.h,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer Glow
              Container(
                width: 260.w,
                height: 260.h,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: speedColor.withOpacity(0.15),
                      blurRadius: 40,
                      spreadRadius: 10,
                    ),
                  ],
                ),
              ),
              CustomPaint(
                size: Size(280.w, 280.h),
                painter: SpeedGaugePainter(
                  speed: speedValue,
                  maxSpeed: 200,
                  color: speedColor,
                ),
              ),
              // Inner Data Ring
              Container(
                width: 190.w,
                height: 190.h,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark
                      ? const Color(0xFF0A0E27).withOpacity(0.8)
                      : Colors.white.withOpacity(0.8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 15,
                    )
                  ],
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        speedValue.toInt().toString(),
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 64.sp,
                          height: 1.0,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Roboto', // Or your preferred tech font
                        ),
                      ),
                      Text(
                        'KM/H',
                        style: TextStyle(
                          color: isDark ? Colors.white54 : Colors.black54,
                          fontSize: 14.sp,
                          letterSpacing: 3,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSmoothAcceleration(double targetAccel, bool isDark) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: targetAccel),
      duration: const Duration(milliseconds: 300),
      builder: (context, accelValue, child) {
        Color accelColor = _getHeatColor(accelValue.abs(), 5);
        return SizedBox(
          width: 130.w,
          height: 130.h,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size(130.w, 130.h),
                painter: MiniGaugePainter(
                  value: accelValue.abs(),
                  maxValue: 10,
                  color: accelColor,
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    accelValue >= 0 ? Icons.keyboard_double_arrow_up : Icons.keyboard_double_arrow_down,
                    color: accelColor,
                    size: 24.r,
                  ),
                  Text(
                    accelValue.abs().toStringAsFixed(1),
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 26.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'm/s²',
                    style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 11.sp),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSmoothGForceRadar(double targetG, double latX, double latY, bool isDark) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: targetG),
      duration: const Duration(milliseconds: 300),
      builder: (context, gValue, child) {
        Color gColor = _getHeatColor(gValue.abs(), 3);
        return SizedBox(
          width: 130.w,
          height: 130.h,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size(130.w, 130.h),
                painter: RadarPainter(animation: _radarController),
              ),
              // Smooth transition for the G-force dot
              TweenAnimationBuilder<Offset>(
                tween: Tween<Offset>(begin: Offset.zero, end: Offset(latX, latY)),
                duration: const Duration(milliseconds: 200),
                builder: (context, offsetValue, child) {
                  return CustomPaint(
                    size: Size(130.w, 130.h),
                    painter: GForceDirectionPainter(
                      lateralX: offsetValue.dx,
                      lateralY: offsetValue.dy,
                      color: gColor,
                    ),
                  );
                },
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    gValue.abs().toStringAsFixed(1),
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 26.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'G',
                    style: TextStyle(color: gColor, fontSize: 14.sp, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ---- UI Components ----

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: EdgeInsets.all(10.r),
              decoration: BoxDecoration(
                color: const Color(0xFF8B7CFF).withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF8B7CFF).withOpacity(0.5), width: 1.5),
              ),
              child: Icon(Icons.arrow_back, color: const Color(0xFF8B7CFF), size: 22.r),
            ),
          ),
          Container(
            padding: EdgeInsets.all(10.r),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.settings_outlined, color: Colors.white54, size: 22.r),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningBanner(String message) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 30.w, vertical: 10.h),
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: const Color(0xFFFF9800).withOpacity(0.15),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFFF9800).withOpacity(0.8), width: 1.5),
        boxShadow: [
          BoxShadow(color: const Color(0xFFFF9800).withOpacity(0.2), blurRadius: 10, spreadRadius: 1),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.warning_amber_rounded, color: const Color(0xFFFF9800), size: 22.r),
          SizedBox(width: 10.w),
          Text(
            'WARNING: $message',
            style: TextStyle(
              color: const Color(0xFFFF9800),
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTurnIndicator(String direction) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 20.w),
      decoration: BoxDecoration(
        color: const Color(0xFF00E5FF).withOpacity(0.9),
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(color: const Color(0xFF00E5FF).withOpacity(0.4), blurRadius: 15),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (direction == "left") Icon(Icons.keyboard_double_arrow_left, color: const Color(0xFF0A0E27), size: 24.r),
          SizedBox(width: direction == "left" ? 8.w : 0),
          Text(
            direction.toUpperCase(),
            style: TextStyle(
              color: const Color(0xFF0A0E27),
              fontSize: 14.sp,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          SizedBox(width: direction == "right" ? 8.w : 0),
          if (direction == "right") Icon(Icons.keyboard_double_arrow_right, color: const Color(0xFF0A0E27), size: 24.r),
        ],
      ),
    );
  }

  Widget _buildRiskIndicator(String riskLevel) {
    Color riskColor = _getRiskColor(riskLevel);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      margin: EdgeInsets.symmetric(horizontal: 40.w),
      padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 30.w),
      decoration: BoxDecoration(
        color: riskColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(30.r),
        border: Border.all(color: riskColor.withOpacity(0.5), width: 2),
        boxShadow: [
          BoxShadow(color: riskColor.withOpacity(0.1), blurRadius: 20),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Icon(
              riskLevel == "High" ? Icons.error_outline :
              riskLevel == "Medium" ? Icons.warning_amber : Icons.shield_outlined,
              key: ValueKey(riskLevel),
              color: riskColor,
              size: 24.r,
            ),
          ),
          SizedBox(width: 12.w),
          Text(
            'SYSTEM RISK: ${riskLevel.toUpperCase()}',
            style: TextStyle(
              color: riskColor,
              fontSize: 13.sp,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}

// ---- Custom Painters ----

class GridBackgroundPainter extends CustomPainter {
  final Animation<double> animation;
  GridBackgroundPainter({required this.animation}) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF8B7CFF).withOpacity(0.05)
      ..strokeWidth = 1;

    double spacing = 50;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    final pulsePaint = Paint()
      ..color = const Color(0xFF8B7CFF).withOpacity(0.15 * animation.value)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(size.width / 2, size.height / 2.5), 200 * animation.value, pulsePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class SpeedGaugePainter extends CustomPainter {
  final double speed;
  final double maxSpeed;
  final Color color;

  SpeedGaugePainter({required this.speed, required this.maxSpeed, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Track Background
    final bgPaint = Paint()
      ..color = const Color(0xFF8B7CFF).withOpacity(0.05)
      ..strokeWidth = 18
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(Rect.fromCircle(center: center, radius: radius - 15), -pi * 0.8, pi * 1.6, false, bgPaint);

    // Active Speed Arc
    final speedPaint = Paint()
      ..shader = SweepGradient(
        colors: [const Color(0xFF00E5FF), color],
        startAngle: -pi * 0.8,
        endAngle: pi * 0.8,
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..strokeWidth = 18
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    double sweepAngle = (speed / maxSpeed).clamp(0.0, 1.0) * pi * 1.6;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius - 15), -pi * 0.8, sweepAngle, false, speedPaint);

    // Ticks
    final tickPaint = Paint()..color = Colors.white24..strokeWidth = 2;
    for (int i = 0; i <= 10; i++) {
      double angle = -pi * 0.8 + (pi * 1.6) * (i / 10);
      double startRadius = radius - 35;
      double endRadius = radius - 26;

      canvas.drawLine(
        Offset(center.dx + startRadius * cos(angle), center.dy + startRadius * sin(angle)),
        Offset(center.dx + endRadius * cos(angle), center.dy + endRadius * sin(angle)),
        tickPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant SpeedGaugePainter oldDelegate) => oldDelegate.speed != speed;
}

class MiniGaugePainter extends CustomPainter {
  final double value;
  final double maxValue;
  final Color color;

  MiniGaugePainter({required this.value, required this.maxValue, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final bgPaint = Paint()
      ..color = const Color(0xFF8B7CFF).withOpacity(0.1)
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(Rect.fromCircle(center: center, radius: radius - 10), -pi * 0.75, pi * 1.5, false, bgPaint);

    final valuePaint = Paint()
      ..color = color
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    double sweepAngle = (value / maxValue).clamp(0.0, 1.0) * pi * 1.5;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius - 10), -pi * 0.75, sweepAngle, false, valuePaint);
  }

  @override
  bool shouldRepaint(covariant MiniGaugePainter oldDelegate) => oldDelegate.value != value;
}

class RadarPainter extends CustomPainter {
  final Animation<double> animation;
  RadarPainter({required this.animation}) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    final circlePaint = Paint()
      ..color = const Color(0xFF8B7CFF).withOpacity(0.15)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    for (int i = 1; i <= 3; i++) {
      canvas.drawCircle(center, maxRadius * (i / 3), circlePaint);
    }

    final sweepPaint = Paint()
      ..shader = SweepGradient(
        colors: [Colors.transparent, const Color(0xFF00E5FF).withOpacity(0.5)],
        stops: const [0.8, 1.0],
        transform: GradientRotation(animation.value * 2 * pi),
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius))
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, maxRadius, sweepPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class GForceDirectionPainter extends CustomPainter {
  final double lateralX;
  final double lateralY;
  final Color color;

  GForceDirectionPainter({required this.lateralX, required this.lateralY, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2.5;

    double normalizedX = (lateralX / 10).clamp(-1.0, 1.0);
    double normalizedY = (lateralY / 10).clamp(-1.0, 1.0);

    Offset forcePoint = Offset(
      center.dx + normalizedX * maxRadius,
      center.dy + normalizedY * maxRadius,
    );

    final linePaint = Paint()
      ..color = color.withOpacity(0.5)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    canvas.drawLine(center, forcePoint, linePaint);

    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4);

    canvas.drawCircle(forcePoint, 6, dotPaint);
  }

  @override
  bool shouldRepaint(covariant GForceDirectionPainter oldDelegate) =>
      oldDelegate.lateralX != lateralX || oldDelegate.lateralY != lateralY;
}