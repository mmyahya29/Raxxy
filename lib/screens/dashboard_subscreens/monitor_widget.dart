import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:raxxy/providers/vehicle_provider.dart';
import 'package:raxxy/screens/dashboard_screen.dart';
import '../../providers/provider.dart';
import 'live_dashboard.dart';

Widget monitorWidget(BuildContext context, DashboardScreen widget) {
  return Consumer(
    builder: (context, ref, _) {
      final monitor = ref.watch(vehicleMonitorProvider);
      final isDark = Theme.of(context).brightness == Brightness.dark;

      // EMPTY STATE: Start Session
      if (monitor.vehicleId == null) {
        return InkWell(
          onTap: () => widget.controller.jumpToTab(2),
          borderRadius: BorderRadius.circular(24.r),
          child: Container(
            height: 70.h,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [Colors.blueGrey.shade800, Colors.blueGrey.shade900]
                    : [Colors.blue.shade50, Colors.white],
              ),
              borderRadius: BorderRadius.circular(24.r),
              border: Border.all(color: Colors.blueAccent.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.play_circle_fill_rounded, color: Colors.blueAccent, size: 28.r),
                SizedBox(width: 12.w),
                Text(
                  'Tap to start a Driving Session',
                  style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, color: Colors.blueAccent),
                ),
              ],
            ),
          ),
        );
      }

      // ACTIVE STATE: Telemetry Dashboard
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(30.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [

            // Add "Full View" button to navigate to live driving screen
            Padding(
              padding: EdgeInsets.all(10.r),
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LiveDrivingScreen(),
                    ),
                  );
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xff6a11cb), Color(0xff2575fc)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20.r),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xff2575fc).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.dashboard_customize_rounded,
                        color: Colors.white,
                        size: 18.r,
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        'Full View',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Top Telemetry Card
            _buildCurrentMonitor(context, monitor, widget),

            // Graph Section
            Container(
              height: 220.h,
              margin: EdgeInsets.fromLTRB(15.w, 0, 15.w, 15.h),
              padding: EdgeInsets.all(16.r),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xff1a1a2e) : const Color(0xfff8f9fe),
                borderRadius: BorderRadius.circular(24.r),
                border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
              ),
              child: _buildMetricsGraph(monitor),
            ),
          ],
        ),
      );
    },
  );
}

Widget _buildCurrentMonitor(BuildContext context, dynamic monitor, DashboardScreen widget) {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  Color riskColor = const Color(0xff4CAF50); // Default Green
  if (monitor.riskLevel == "Medium") riskColor = const Color(0xffFF9800);
  if (monitor.riskLevel == "High") riskColor = const Color(0xffF44336);

  return InkWell(
    onTap: () {
      // Navigate to live driving screen on tap
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const LiveDrivingScreen(),
        ),
      );
    },
    child: Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xff2d2d44), const Color(0xff1c1c2e)]
              : [const Color(0xFFE8EAF6), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(30.r)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${monitor.make ?? "Vehicle"} ${monitor.model ?? ""}'.toUpperCase(),
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w900,
                        color: Colors.blueAccent,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    // Add a small indicator that this is tappable
                    Icon(
                      Icons.open_in_full_rounded,
                      size: 16.r,
                      color: Colors.blueAccent.withOpacity(0.6),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                _telemetryRow(Icons.speed_rounded, "Speed", "${monitor.speed.toStringAsFixed(1)} km/h"),
                _telemetryRow(Icons.shutter_speed_rounded, "Accel", "${monitor.acceleration.toStringAsFixed(1)} m/s²"),
                _telemetryRow(Icons.map_rounded, "Dist", "${(monitor.distance / 1000).toStringAsFixed(2)} km"),
              ],
            ),
          ),

          // Risk Indicator
          Expanded(
            flex: 1,
            child: Container(
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(
                color: riskColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(color: riskColor.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Icon(Icons.warning_amber_rounded, color: riskColor, size: 24.r),
                  Text(
                    "RISK",
                    style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.bold, color: riskColor),
                  ),
                  Text(
                    "${monitor.riskScore}",
                    style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.w900, color: riskColor),
                  ),
                  Text(
                    "${monitor.riskLevel}",
                    style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: riskColor),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _telemetryRow(IconData icon, String label, String value) {
  return Padding(
    padding: EdgeInsets.only(bottom: 4.h),
    child: Row(
      children: [
        Icon(icon, size: 14.r, color: Colors.grey),
        SizedBox(width: 6.w),
        Text("$label: ", style: TextStyle(fontSize: 13.sp, color: Colors.grey)),
        Text(value, style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold)),
      ],
    ),
  );
}

Widget _buildMetricsGraph(dynamic monitor) {
  final speedData = monitor.speedHistory;
  final accData = monitor.accelerationHistory;

  return LineChart(
    LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.withOpacity(0.1), strokeWidth: 1),
      ),
      titlesData: FlTitlesData(
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 22,
            getTitlesWidget: (val, _) => Text("${val.toInt()}s", style: const TextStyle(color: Colors.grey, fontSize: 10)),
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        // Speed Line (Green)
        LineChartBarData(
          spots: List.generate(speedData.length, (i) => FlSpot(i.toDouble(), speedData[i])),
          isCurved: true,
          color: Colors.greenAccent,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: [Colors.greenAccent.withOpacity(0.2), Colors.transparent],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        // Acceleration Line (Red)
        LineChartBarData(
          spots: List.generate(accData.length, (i) => FlSpot(i.toDouble(), accData[i])),
          isCurved: true,
          color: Colors.redAccent,
          barWidth: 2,
          dashArray: [5, 5],
          dotData: FlDotData(show: false),
        ),
      ],
    ),
  );
}