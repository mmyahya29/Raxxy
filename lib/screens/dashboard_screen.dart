import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:persistent_bottom_nav_bar/persistent_bottom_nav_bar.dart';
import 'package:raxxy/providers/theme_provider.dart';
import 'package:raxxy/providers/vehicle_provider.dart';
import 'package:raxxy/screens/dashboard_subscreens/goals_widget.dart';
import '../providers/goals_provider.dart';
import '../providers/provider.dart';
import '../services/maintenance_service.dart';
import 'dashboard_subscreens/driver_profile_widget.dart';
import 'dashboard_subscreens/track_management_screen.dart';
import 'maintenance_subscreens/maintenance_widget.dart';
import 'dashboard_subscreens/monitor_widget.dart';
import 'maintenance_subscreens/summary_widget.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  final PersistentTabController controller;

  const DashboardScreen({super.key, required this.controller});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeNotifierProvider);
    final isDark =
        themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0A0E27) : const Color(0xFFF4F5F9),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- CUSTOM APP BAR ---
              _buildCustomAppBar(isDark),

              // --- DRIVING SCORE HEADER ---
              _buildAnimatedScoreHeader(context, isDark),

              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 25.h),

                    // --- MONITOR SECTION ---
                    _buildHudSectionHeader(
                      'ACTIVE TELEMETRY',
                      Icons.sensors_rounded,
                      const Color(0xFF00E5FF),
                      isDark,
                    ),
                    SizedBox(height: 15.h),
                    monitorWidget(context, widget),

                    SizedBox(height: 30.h),

                    // --- DRIVER PROFILE ---
                    _buildHudSectionHeader(
                      'PILOT METRICS',
                      Icons.psychology_rounded,
                      const Color(0xFF8B7CFF),
                      isDark,
                    ),
                    SizedBox(height: 15.h),
                    driverProfileWidget(context),

                    SizedBox(height: 30.h),

                    // --- ACTIVE GOALS ---
                    _buildHudSectionHeader(
                      'ACTIVE DIRECTIVES',
                      Icons.track_changes_rounded,
                      const Color(0xFFFF9800),
                      isDark,
                    ),
                    SizedBox(height: 15.h),
                    goalsWidget(context, () => setState(() {})),

                    SizedBox(height: 40.h),
                    // Bottom padding for nav bar clearance
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- UI Components ---

  Widget _buildCustomAppBar(bool isDark) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 10.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SYSTEM OVERVIEW',
                style: TextStyle(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white54 : Colors.grey,
                  letterSpacing: 2,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                'Welcome back, Pilot.',
                style: TextStyle(
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF0A0E27),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => TrackManagementScreen()),
              );
            },
            child: Container(
              padding: EdgeInsets.all(10.r),
              decoration: BoxDecoration(
                color:
                    isDark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.black.withOpacity(0.05),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? Colors.white10 : Colors.black12,
                ),
              ),
              child: Icon(
                Icons.edit_road_rounded,
                color: isDark ? Colors.white70 : Colors.black87,
                size: 24.r,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedScoreHeader(BuildContext context, bool isDark) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
      padding: EdgeInsets.all(24.r),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8B7CFF), Color(0xFF00E5FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30.r),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E5FF).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
            spreadRadius: 2,
          ),
        ],
      ),
      child: Consumer(
        builder: (context, ref, _) {
          final driveScoreAsync = ref.watch(driveScoreProvider);

          return driveScoreAsync.when(
            data: (score) {
              final safeScore = (score ?? 0).toDouble();
              final statusColor = _getScoreColor(safeScore);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "GLOBAL SAFETY RATING",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                      Icon(
                        Icons.shield_rounded,
                        color: Colors.white.withOpacity(0.9),
                        size: 20.r,
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0, end: safeScore),
                        duration: const Duration(milliseconds: 1500),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) {
                          return Text(
                            value.toStringAsFixed(1),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 48.sp,
                              fontWeight: FontWeight.w900,
                              height: 1.0,
                            ),
                          );
                        },
                      ),
                      SizedBox(width: 8.w),
                      Padding(
                        padding: EdgeInsets.only(bottom: 6.h),
                        child: Text(
                          "/ 100",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 6.h,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20.r),
                          border: Border.all(
                            color: statusColor.withOpacity(0.5),
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          _getScoreLabel(safeScore),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20.h),
                  // Animated glowing progress bar
                  Container(
                    height: 8.h,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(
                            begin: 0,
                            end: (safeScore / 100).clamp(0.0, 1.0),
                          ),
                          duration: const Duration(milliseconds: 1500),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) {
                            return FractionallySizedBox(
                              widthFactor: value,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  borderRadius: BorderRadius.circular(10.r),
                                  boxShadow: [
                                    BoxShadow(
                                      color: statusColor.withOpacity(0.8),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
            loading:
                () => SizedBox(
                  height: 120.h,
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
            error:
                (e, _) => SizedBox(
                  height: 120.h,
                  child: Center(
                    child: Text(
                      "TELEMETRY ERROR\n$e",
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
          );
        },
      ),
    );
  }

  Widget _buildHudSectionHeader(
    String title,
    IconData icon,
    Color accentColor,
    bool isDark,
  ) {
    return Row(
      children: [
        Icon(icon, size: 18.r, color: accentColor),
        SizedBox(width: 8.w),
        Text(
          title,
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : const Color(0xFF0A0E27),
            letterSpacing: 1.5,
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Container(
            height: 1.5,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [accentColor.withOpacity(0.5), Colors.transparent],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- Helpers ---

  String _getScoreLabel(double score) {
    if (score >= 90) return "OPTIMAL";
    if (score >= 75) return "NOMINAL";
    if (score >= 50) return "WARNING";
    return "CRITICAL";
  }

  Color _getScoreColor(double score) {
    if (score >= 90) return const Color(0xFF4CAF50); // Green
    if (score >= 75) return const Color(0xFF00E5FF); // Cyan
    if (score >= 50) return const Color(0xFFFF9800); // Orange
    return const Color(0xFFFF5252); // Red
  }
}
