import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:raxxy/providers/theme_provider.dart';
import 'package:raxxy/providers/vehicle_provider.dart';
import 'package:raxxy/screens/dashboard_screen.dart';
import '../../providers/provider.dart';
import 'live_dashboard.dart';

// Wrapper to maintain your exact current API
Widget monitorWidget(BuildContext context, DashboardScreen widget) {
  return AnimatedMonitorDashboard(dashboardWidget: widget);
}

class AnimatedMonitorDashboard extends ConsumerStatefulWidget {
  final DashboardScreen dashboardWidget;

  const AnimatedMonitorDashboard({Key? key, required this.dashboardWidget}) : super(key: key);

  @override
  ConsumerState<AnimatedMonitorDashboard> createState() => _AnimatedMonitorDashboardState();
}

class _AnimatedMonitorDashboardState extends ConsumerState<AnimatedMonitorDashboard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Color _getRiskColor(String? riskLevel) {
    if (riskLevel == "Medium") return const Color(0xffFF9800);
    if (riskLevel == "High") return const Color(0xffF44336);
    return const Color(0xff4CAF50); // Default Low
  }

  @override
  Widget build(BuildContext context) {
    final monitor = ref.watch(vehicleMonitorProvider);
    final themeMode = ref.watch(themeNotifierProvider);
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 600),
      switchInCurve: Curves.easeOutBack,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(animation),
            child: child,
          ),
        );
      },
      // Check if session is active
      child: monitor.vehicleId == null
          ? _buildEmptyState(isDark)
          : _buildActiveDashboard(monitor, isDark),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return KeyedSubtree(
      key: const ValueKey("empty_state"),
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return InkWell(
            onTap: () => widget.dashboardWidget.controller.jumpToTab(2),
            borderRadius: BorderRadius.circular(24.r),
            child: Container(
              height: 75.h,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [
                    const Color(0xFF1E2447).withOpacity(_pulseAnimation.value),
                    const Color(0xFF0A0E27)
                  ]
                      : [
                    Colors.blue.shade50.withOpacity(_pulseAnimation.value),
                    Colors.white
                  ],
                ),
                borderRadius: BorderRadius.circular(24.r),
                border: Border.all(
                  color: const Color(0xFF8B7CFF).withOpacity(0.3 * _pulseAnimation.value),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B7CFF).withOpacity(0.15 * _pulseAnimation.value),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.sensors_rounded,
                    color: const Color(0xFF8B7CFF),
                    size: 28.r,
                  ),
                  SizedBox(width: 12.w),
                  Text(
                    'INITIALIZE TELEMETRY',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF8B7CFF),
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActiveDashboard(dynamic monitor, bool isDark) {
    Color riskColor = _getRiskColor(monitor.riskLevel);

    return KeyedSubtree(
      key: const ValueKey("active_state"),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        width: double.infinity,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1F3A) : Colors.white,
          borderRadius: BorderRadius.circular(30.r),
          border: Border.all(
            color: riskColor.withOpacity(isDark ? 0.3 : 0.5),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: riskColor.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          children: [
            _buildTelemetryHeader(monitor, isDark, riskColor),
            _buildMetricsGrid(monitor, isDark),
            _buildChartSection(monitor, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildTelemetryHeader(dynamic monitor, bool isDark, Color riskColor) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 10.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Vehicle Info
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${monitor.make ?? "RAXXY"} ${monitor.model ?? "SYSTEM"}'.toUpperCase(),
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : Colors.black87,
                  letterSpacing: 1.2,
                ),
              ),
              SizedBox(height: 4.h),
              Row(
                children: [
                  Container(
                    width: 8.r,
                    height: 8.r,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E5FF),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: const Color(0xFF00E5FF).withOpacity(0.5), blurRadius: 4),
                      ],
                    ),
                  ),
                  SizedBox(width: 6.w),
                  Text(
                    "LIVE DATA",
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF00E5FF),
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Action Button mapping to Full View
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LiveDrivingScreen()),
              );
            },
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8B7CFF), Color(0xFF00E5FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20.r),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00E5FF).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.open_in_new_rounded, color: Colors.white, size: 16.r),
                  SizedBox(width: 6.w),
                  Text(
                    'EXPAND',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
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

  Widget _buildMetricsGrid(dynamic monitor, bool isDark) {
    Color riskColor = _getRiskColor(monitor.riskLevel);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 15.w, vertical: 10.h),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _buildSmoothMetricBlock("SPEED", monitor.speed, "km/h", const Color(0xFF00E5FF), isDark)),
                    SizedBox(width: 10.w),
                    Expanded(child: _buildSmoothMetricBlock("ACCEL", monitor.acceleration, "m/s²", const Color(0xFF8B7CFF), isDark)),
                  ],
                ),
                SizedBox(height: 10.h),
                _buildSmoothMetricBlock("DISTANCE", monitor.distance / 1000, "km", const Color(0xFF4CAF50), isDark, isWide: true),
              ],
            ),
          ),
          SizedBox(width: 10.w),
          // Risk Score Block
          Expanded(
            flex: 1,
            child: Container(
              height: 110.h, // Matches the height of the two rows + spacing
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(
                color: riskColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(color: riskColor.withOpacity(0.3)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.security_rounded, color: riskColor, size: 22.r),
                  SizedBox(height: 4.h),
                  Text(
                    "RISK",
                    style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.bold, color: riskColor),
                  ),
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: (monitor.riskScore ?? 0).toDouble()),
                    duration: const Duration(milliseconds: 400),
                    builder: (context, val, child) {
                      return Text(
                        val.toInt().toString(),
                        style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.w900, color: riskColor),
                      );
                    },
                  ),
                  Text(
                    "${monitor.riskLevel}".toUpperCase(),
                    style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w800, color: riskColor),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmoothMetricBlock(String label, double value, String unit, Color color, bool isDark, {bool isWide = false}) {
    return Container(
      height: 50.h,
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0A0E27) : const Color(0xFFF4F5F9),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: isWide
          ? Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 10.sp, color: Colors.grey, fontWeight: FontWeight.bold)),
          _buildAnimatedValue(value, unit, color),
        ],
      )
          : Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: TextStyle(fontSize: 9.sp, color: Colors.grey, fontWeight: FontWeight.bold)),
          _buildAnimatedValue(value, unit, color),
        ],
      ),
    );
  }

  Widget _buildAnimatedValue(double value, String unit, Color color) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value),
      duration: const Duration(milliseconds: 300),
      builder: (context, val, child) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              val.toStringAsFixed(1),
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            SizedBox(width: 2.w),
            Text(
              unit,
              style: TextStyle(fontSize: 9.sp, color: color.withOpacity(0.7), fontWeight: FontWeight.w600),
            ),
          ],
        );
      },
    );
  }

  Widget _buildChartSection(dynamic monitor, bool isDark) {
    final speedData = monitor.speedHistory as List<double>? ?? [0.0];
    final accData = monitor.accelerationHistory as List<double>? ?? [0.0];

    return Container(
      height: 180.h,
      margin: EdgeInsets.fromLTRB(15.w, 5.h, 15.w, 15.h),
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0A0E27) : const Color(0xFFF8F9FE),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
          )
        ],
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: const Color(0xFF8B7CFF).withOpacity(0.1),
              strokeWidth: 1,
              dashArray: [5, 5],
            ),
          ),
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), // Cleaner look
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                getTitlesWidget: (val, _) => Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    "${val.toInt()}s",
                    style: TextStyle(
                      color: isDark ? Colors.white54 : Colors.grey,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            // Speed Line (Cyan to Blue Gradient)
            LineChartBarData(
              spots: List.generate(speedData.length, (i) => FlSpot(i.toDouble(), speedData[i])),
              isCurved: true,
              curveSmoothness: 0.35,
              gradient: const LinearGradient(colors: [Color(0xFF00E5FF), Color(0xFF2196F3)]),
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF00E5FF).withOpacity(0.3),
                    const Color(0xFF2196F3).withOpacity(0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            // Acceleration Line (Purple dashed)
            LineChartBarData(
              spots: List.generate(accData.length, (i) => FlSpot(i.toDouble(), accData[i])),
              isCurved: true,
              color: const Color(0xFF8B7CFF),
              barWidth: 2,
              dashArray: [6, 4],
              dotData: const FlDotData(show: false),
            ),
          ],
        ),
      ),
    );
  }
}