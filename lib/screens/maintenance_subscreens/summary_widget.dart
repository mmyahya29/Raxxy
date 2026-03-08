import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:raxxy/providers/vehicle_provider.dart';
import '../../providers/summary_provider.dart';
import '../../services/maintenance_service.dart';

Widget summaryWidget(BuildContext context, VoidCallback rebuild) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;

  return Container(
    height: 480.h, // Slightly taller to accommodate the new card layouts comfortably
    width: MediaQuery.of(context).size.width - 40.w,
    decoration: BoxDecoration(
      color: isDark ? const Color(0xFF1A1F3A) : Colors.white,
      borderRadius: BorderRadius.circular(30.r),
      border: Border.all(
        color: isDark ? const Color(0xFF8B7CFF).withOpacity(0.3) : Colors.blue.withOpacity(0.2),
        width: 1.5,
      ),
      boxShadow: [
        BoxShadow(
          color: isDark ? const Color(0xFF8B7CFF).withOpacity(0.05) : Colors.black.withOpacity(0.05),
          blurRadius: 20,
          spreadRadius: 2,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    padding: EdgeInsets.only(top: 20.h, bottom: 10.h),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          child: Row(
            children: [
              Icon(Icons.history_rounded, color: const Color(0xFF8B7CFF), size: 22.r),
              SizedBox(width: 8.w),
              Text(
                'SESSION ARCHIVE',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF8B7CFF),
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 15.h),

        // Data List
        Expanded(
          child: Consumer(
            builder: (context, ref, _) {
              final summaries = ref.watch(summaryProvider);

              return summaries.when(
                data: (list) {
                  if (list.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.data_array_rounded, size: 45.sp, color: isDark ? Colors.white24 : Colors.grey.withOpacity(0.5)),
                          SizedBox(height: 12.h),
                          Text(
                            "NO RECORDED SESSIONS",
                            style: TextStyle(
                              color: isDark ? Colors.white54 : Colors.grey,
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.symmetric(horizontal: 15.w, vertical: 5.h),
                    itemCount: list.length,
                    separatorBuilder: (context, index) => SizedBox(height: 15.h),
                    itemBuilder: (context, index) {
                      final sum = list[index];
                      return _buildSessionCard(sum.data(), context, isDark);
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF8B7CFF))),
                error: (e, _) => Center(child: Text("System Error: $e", style: const TextStyle(color: Colors.redAccent))),
              );
            },
          ),
        ),
      ],
    ),
  );
}

Widget _buildSessionCard(Map<String, dynamic> sum, BuildContext context, bool isDark) {
  final startTime = (sum["startTime"] as Timestamp).toDate();
  final distance = (sum["distanceKm"] as num).toDouble();
  final avgSpeed = (sum["avgSpeedKmh"] as num).toDouble();
  final durationMin = sum["durationMinutes"] ?? 0;
  final harshEvents = sum["totalHarshEvents"] ?? 0;

  return Container(
    decoration: BoxDecoration(
      color: isDark ? const Color(0xFF0A0E27) : const Color(0xFFF8F9FE),
      borderRadius: BorderRadius.circular(24.r),
      border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Card Header (Timestamp & Basic Info)
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.03) : Colors.blueAccent.withOpacity(0.05),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.route_outlined, color: const Color(0xFF00E5FF), size: 18.r),
                  SizedBox(width: 8.w),
                  Text(
                    _formatDate(startTime),
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: harshEvents > 0 ? const Color(0xFFFF5252).withOpacity(0.2) : const Color(0xFF4CAF50).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  harshEvents > 0 ? "$harshEvents ALERTS" : "CLEAN RUN",
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w900,
                    color: harshEvents > 0 ? const Color(0xFFFF5252) : const Color(0xFF4CAF50),
                  ),
                ),
              ),
            ],
          ),
        ),

        Padding(
          padding: EdgeInsets.all(16.r),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Core Metrics Grid
              Row(
                children: [
                  Expanded(child: _buildHudMetric("DISTANCE", distance.toStringAsFixed(1), "km", const Color(0xFF00E5FF), isDark)),
                  SizedBox(width: 10.w),
                  Expanded(child: _buildHudMetric("AVG SPEED", avgSpeed.toStringAsFixed(1), "km/h", const Color(0xFF8B7CFF), isDark)),
                  SizedBox(width: 10.w),
                  Expanded(child: _buildHudMetric("DURATION", "$durationMin", "min", const Color(0xFFFF9800), isDark)),
                ],
              ),
              SizedBox(height: 16.h),

              // Telemetry Pills
              Wrap(
                spacing: 8.w,
                runSpacing: 8.h,
                children: [
                  _buildDataPill(Icons.warning_amber_rounded, "Harsh: $harshEvents", const Color(0xFFFF5252), isDark),
                  _buildDataPill(Icons.turn_slight_right_rounded, "Turns: ${sum["totalTurns"]}", const Color(0xFF2196F3), isDark),
                  _buildDataPill(Icons.swap_calls_rounded, "Switches: ${sum["totalSwitches"]}", const Color(0xFF9C27B0), isDark),
                  _buildDataPill(Icons.timer_outlined, "Stopped: ${sum["stoppedTimeSeconds"]}s", Colors.grey, isDark),
                ],
              ),
              SizedBox(height: 16.h),

              // Environment Analysis
              Text(
                "ENVIRONMENT ANALYSIS",
                style: TextStyle(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white54 : Colors.grey,
                  letterSpacing: 1,
                ),
              ),
              SizedBox(height: 8.h),
              _buildAnimatedProbabilityRow("City Driving", (sum["cityProbability"] as num).toDouble(), const Color(0xFF00E5FF), isDark),
              SizedBox(height: 6.h),
              _buildAnimatedProbabilityRow("Highway Driving", (sum["highwayProbability"] as num).toDouble(), const Color(0xFF8B7CFF), isDark),
            ],
          ),
        ),
      ],
    ),
  );
}

// ---- Custom HUD Widgets ----

Widget _buildHudMetric(String label, String value, String unit, Color accentColor, bool isDark) {
  return Container(
    padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 8.w),
    decoration: BoxDecoration(
      color: isDark ? Colors.white.withOpacity(0.02) : Colors.white,
      borderRadius: BorderRadius.circular(16.r),
      border: Border.all(color: accentColor.withOpacity(0.2)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 9.sp, fontWeight: FontWeight.bold, color: isDark ? Colors.white54 : Colors.black54),
        ),
        SizedBox(height: 4.h),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w900, color: accentColor),
            ),
            SizedBox(width: 2.w),
            Text(
              unit,
              style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w600, color: accentColor.withOpacity(0.7)),
            ),
          ],
        ),
      ],
    ),
  );
}

Widget _buildDataPill(IconData icon, String text, Color color, bool isDark) {
  return Container(
    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12.r),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14.r, color: color),
        SizedBox(width: 4.w),
        Text(
          text,
          style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w700, color: color),
        ),
      ],
    ),
  );
}

Widget _buildAnimatedProbabilityRow(String label, double probability, Color color, bool isDark) {
  return Row(
    children: [
      SizedBox(
        width: 85.w,
        child: Text(
          label,
          style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black87),
        ),
      ),
      SizedBox(width: 8.w),
      Expanded(
        child: Container(
          height: 6.h,
          decoration: BoxDecoration(
            color: isDark ? Colors.black26 : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(4.r),
          ),
          child: Stack(
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: probability),
                duration: const Duration(milliseconds: 1000),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return FractionallySizedBox(
                    widthFactor: value.clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(4.r),
                        boxShadow: [
                          BoxShadow(color: color.withOpacity(0.5), blurRadius: 4),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      SizedBox(width: 10.w),
      SizedBox(
        width: 40.w,
        child: Text(
          "${(probability * 100).toStringAsFixed(0)}%",
          textAlign: TextAlign.right,
          style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w800, color: color),
        ),
      ),
    ],
  );
}

// Simple date formatter to keep dependencies clean
String _formatDate(DateTime date) {
  final monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
  String pad(int n) => n.toString().padLeft(2, '0');
  String amPm = date.hour >= 12 ? "PM" : "AM";
  int hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
  return "${monthNames[date.month - 1]} ${date.day}, ${date.year} • $hour:${pad(date.minute)} $amPm";
}