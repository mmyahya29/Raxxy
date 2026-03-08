import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:persistent_bottom_nav_bar/persistent_bottom_nav_bar.dart';
import 'package:raxxy/providers/theme_provider.dart';
import 'maintenance_subscreens/maintenance_widget.dart';
import 'dashboard_subscreens/monitor_widget.dart';
import 'maintenance_subscreens/summary_widget.dart';

class MaintenanceScreen extends ConsumerStatefulWidget {
  final PersistentTabController controller;

  const MaintenanceScreen({super.key, required this.controller});

  @override
  ConsumerState<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends ConsumerState<MaintenanceScreen> {
  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeNotifierProvider);
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0E27) : const Color(0xFFF4F5F9),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- CUSTOM HEADER ---
              _buildCustomAppBar(isDark),

              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 10.h),

                    // --- DIAGNOSTICS & LOGS ---
                    _buildHudSectionHeader('SYSTEM DIAGNOSTICS', Icons.build_circle_outlined, const Color(0xFF00E5FF), isDark),
                    SizedBox(height: 15.h),
                    maintenanceLogWidget(context, () => setState(() {})),

                    SizedBox(height: 35.h),

                    // --- AI ASSISTANT ---
                    _buildHudSectionHeader('AI TROUBLESHOOTING', Icons.smart_toy_outlined, const Color(0xFF8B5CF6), isDark),
                    SizedBox(height: 10.h),
                    const AnimatedChatbotCardWidget(),

                    SizedBox(height: 35.h),

                    // --- SESSION ARCHIVE ---
                    _buildHudSectionHeader('SESSION ARCHIVE', Icons.history_rounded, const Color(0xFF8B7CFF), isDark),
                    SizedBox(height: 15.h),
                    summaryWidget(context, () => setState(() {})),

                    SizedBox(height: 40.h), // Bottom padding for nav bar clearance
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
      padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 20.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MAINTENANCE BAY',
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white54 : Colors.grey,
                    letterSpacing: 2,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'Diagnostics & History',
                  style: TextStyle(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF0A0E27),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.all(12.r),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF00E5FF).withOpacity(0.1) : const Color(0xFF00E5FF).withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.3)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00E5FF).withOpacity(0.2),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              Icons.handyman_rounded,
              color: const Color(0xFF00E5FF),
              size: 24.r,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHudSectionHeader(String title, IconData icon, Color accentColor, bool isDark) {
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
}