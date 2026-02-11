import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:persistent_bottom_nav_bar/persistent_bottom_nav_bar.dart';
import 'package:raxxy/providers/vehicle_provider.dart';
import 'package:raxxy/screens/dashboard_subscreens/goals_widget.dart';
import '../providers/goals_provider.dart';
import '../providers/provider.dart';
import '../services/maintenance_service.dart';
import 'dashboard_subscreens/driver_profile_widget.dart';
import 'maintenance_subscreens/maintenance_widget.dart';
import 'dashboard_subscreens/monitor_widget.dart';
import 'dashboard_subscreens/summary_widget.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  final PersistentTabController controller;
  const DashboardScreen({super.key, required this.controller});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dashboard', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24.sp)),
            Text('Welcome back, Driver', style: TextStyle(fontSize: 14.sp, color: Colors.grey)),
          ],
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xff6a11cb), Color(0xff2575fc)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),

            boxShadow: [
              BoxShadow(
                color: const Color(0xff2575fc).withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- DRIVING SCORE HEADER ---
            _buildScoreHeader(context),

            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 25.h),

                  // --- MONITOR SECTION ---
                  _sectionHeader('Vehicle Status', Icons.directions_car_filled_rounded),
                  SizedBox(height: 12.h),
                  monitorWidget(context, widget),

                  SizedBox(height: 25.h),

                  // --- DRIVER & GOALS (Side by Side or specialized layout) ---
                  _sectionHeader('Performance', Icons.analytics_rounded),
                  SizedBox(height: 12.h),
                  driverProfileWidget(context),

                  SizedBox(height: 25.h),

                  _sectionHeader('Active Goals', Icons.flag_rounded),
                  SizedBox(height: 12.h),
                  goalsWidget(context, () => setState(() {})),

                  SizedBox(height: 25.h),

                  _sectionHeader('Summaries', Icons.summarize_rounded),
                  SizedBox(height: 12.h),
                  summaryWidget(context, () => setState(() {})),

                  SizedBox(height: 30.h),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Modern Score Header with Gradient & Blur feel
  Widget _buildScoreHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xff6a11cb), Color(0xff2575fc)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff2575fc).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Consumer(
        builder: (context, ref, _) {
          final driveScore = ref.watch(driveScoreProvider);

          return driveScore.when(
            data: (score) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Safety Score",
                      style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 16.sp, fontWeight: FontWeight.w500),
                    ),
                    const Icon(Icons.info_outline, color: Colors.white70, size: 20),
                  ],
                ),
                SizedBox(height: 8.h),
                Row(
                  children: [
                    Text(
                      score?.toStringAsFixed(1) ?? 'N/A',
                      style: TextStyle(color: Colors.white, fontSize: 42.sp, fontWeight: FontWeight.w900),
                    ),
                    SizedBox(width: 10.w),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      child: Text(
                        _getScoreLabel(score ?? 0),
                        style: TextStyle(color: Colors.white, fontSize: 12.sp, fontWeight: FontWeight.bold),
                      ),
                    )
                  ],
                ),
                SizedBox(height: 15.h),
                // Visual Progress Bar for the score
                ClipRRect(
                  borderRadius: BorderRadius.circular(10.r),
                  child: LinearProgressIndicator(
                    value: (score ?? 0) / 100,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    color: Colors.white,
                    minHeight: 8.h,
                  ),
                ),
              ],
            ),
            loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
            error: (e, _) => Text("Error: $e", style: const TextStyle(color: Colors.white)),
          );
        },
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20.r, color: const Color(0xffb2b0ff)),
        SizedBox(width: 8.w),
        Text(
          title,
          style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
      ],
    );
  }

  String _getScoreLabel(double score) {
    if (score >= 90) return "EXCELLENT";
    if (score >= 75) return "GOOD";
    if (score >= 50) return "AVERAGE";
    return "CAUTION";
  }
}