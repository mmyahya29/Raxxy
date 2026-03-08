import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:raxxy/providers/driver_profile_provider.dart';
import 'package:raxxy/providers/theme_provider.dart';

class DriverProfileWidget extends ConsumerWidget {
  const DriverProfileWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeNotifierProvider);
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);
    final profileAsync = ref.watch(driverProfileProvider);

    return Container(
      width: MediaQuery.of(context).size.width - 40.w,
      margin: EdgeInsets.symmetric(vertical: 10.h),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1F3A) : Colors.white,
        borderRadius: BorderRadius.circular(30.r),
        border: Border.all(
          color: isDark ? const Color(0xFF8B7CFF).withOpacity(0.3) : Colors.blue.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? const Color(0xFF8B7CFF).withOpacity(0.1) : Colors.black.withOpacity(0.05),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: EdgeInsets.all(24.r),
      child: profileAsync.when(
        data: (profile) {
          final badge = profile['badge'] as Map<String, dynamic>? ?? {'emoji': '🏆', 'tier': 'Unranked'};
          final scores = Map<String, int>.from(profile['scores'] ?? {});
          final traits = List<String>.from(profile['secondaryTraits'] ?? []);
          final recommendations = List<String>.from(profile['recommendations'] ?? []);
          final stressTriggers = List<String>.from(profile['stressTriggers'] ?? []);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProfileHeader(profile['primaryProfile'] ?? 'Unknown Driver', badge, isDark),

              if (stressTriggers.isNotEmpty) ...[
                SizedBox(height: 20.h),
                _buildSectionTitle('STRESS TRIGGERS', const Color(0xFFFF5252), Icons.warning_amber_rounded),
                SizedBox(height: 10.h),
                _buildChipsWrap(stressTriggers, const Color(0xFFFF5252), isDark),
              ],

              if (traits.isNotEmpty) ...[
                SizedBox(height: 20.h),
                _buildSectionTitle('DRIVER TRAITS', const Color(0xFF00E5FF), Icons.psychology_rounded),
                SizedBox(height: 10.h),
                _buildChipsWrap(traits, const Color(0xFF00E5FF), isDark),
              ],

              SizedBox(height: 24.h),
              _buildSectionTitle('PERFORMANCE METRICS', const Color(0xFF8B7CFF), Icons.analytics_outlined),
              SizedBox(height: 15.h),

              _buildAnimatedScoreBar('Overall', scores['overall'] ?? 0, const Color(0xFF8B7CFF), isDark),
              _buildAnimatedScoreBar('Smoothness', scores['smoothness'] ?? 0, const Color(0xFF4CAF50), isDark),
              _buildAnimatedScoreBar('Safety', scores['safety'] ?? 0, const Color(0xFF00E5FF), isDark),
              _buildAnimatedScoreBar('Efficiency', scores['efficiency'] ?? 0, const Color(0xFFFF9800), isDark),

              if (recommendations.isNotEmpty) ...[
                SizedBox(height: 24.h),
                _buildSectionTitle('SYSTEM RECOMMENDATIONS', const Color(0xFFFFC107), Icons.lightbulb_outline),
                SizedBox(height: 12.h),
                ...recommendations.map((rec) => _buildRecommendationItem(rec, isDark)),
              ],
            ],
          );
        },
        loading: () => SizedBox(
          height: 200.h,
          child: const Center(
            child: CircularProgressIndicator(color: Color(0xFF8B7CFF)),
          ),
        ),
        error: (err, stack) => SizedBox(
          height: 200.h,
          child: Center(
            child: Text(
              'SYSTEM ERROR\nUnable to load profile data.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.redAccent, fontSize: 14.sp, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }
}

// Keep the function wrapper for backward compatibility
Widget driverProfileWidget(BuildContext context) {
  return const DriverProfileWidget();
}

// ---- Helper Widgets ----

Widget _buildProfileHeader(String profileName, Map<String, dynamic> badge, bool isDark) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'DRIVER PROFILE',
              style: TextStyle(
                fontSize: 10.sp,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white54 : Colors.grey,
                letterSpacing: 2,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              profileName.toUpperCase(),
              style: TextStyle(
                fontSize: 22.sp,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF0A0E27),
                letterSpacing: 1.2,
              ),
            ),
            SizedBox(height: 6.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: const Color(0xFFFF9800).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: const Color(0xFFFF9800).withOpacity(0.5)),
              ),
              child: Text(
                badge['tier']?.toString().toUpperCase() ?? 'UNRANKED',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFFFF9800),
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
      Container(
        height: 65.r,
        width: 65.r,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFFF9800).withOpacity(0.1),
          border: Border.all(color: const Color(0xFFFF9800).withOpacity(0.3), width: 2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF9800).withOpacity(0.2),
              blurRadius: 15,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Center(
          child: Text(
            badge['emoji']?.toString() ?? '🛡️',
            style: TextStyle(fontSize: 32.sp),
          ),
        ),
      ),
    ],
  );
}

Widget _buildSectionTitle(String title, Color accentColor, IconData icon) {
  return Row(
    children: [
      Icon(icon, size: 16.r, color: accentColor),
      SizedBox(width: 8.w),
      Text(
        title,
        style: TextStyle(
          fontSize: 12.sp,
          fontWeight: FontWeight.w800,
          color: accentColor,
          letterSpacing: 1.5,
        ),
      ),
      SizedBox(width: 10.w),
      Expanded(
        child: Container(
          height: 1,
          color: accentColor.withOpacity(0.2),
        ),
      ),
    ],
  );
}

Widget _buildChipsWrap(List<String> items, Color color, bool isDark) {
  return Wrap(
    spacing: 10.w,
    runSpacing: 10.h,
    children: items.map((item) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: color.withOpacity(0.4), width: 1.5),
        ),
        child: Text(
          item.toUpperCase(),
          style: TextStyle(
            fontSize: 11.sp,
            fontWeight: FontWeight.w700,
            color: color,
            letterSpacing: 0.8,
          ),
        ),
      );
    }).toList(),
  );
}

Widget _buildAnimatedScoreBar(String label, int targetScore, Color color, bool isDark) {
  return Padding(
    padding: EdgeInsets.only(bottom: 16.h),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white70 : Colors.black87,
                letterSpacing: 1,
              ),
            ),
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: targetScore.toDouble()),
              duration: const Duration(milliseconds: 1200),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Text(
                  '${value.toInt()}',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                );
              },
            ),
          ],
        ),
        SizedBox(height: 8.h),
        LayoutBuilder(
          builder: (context, constraints) {
            return Container(
              height: 8.h,
              width: constraints.maxWidth,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0A0E27) : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(4.r),
                boxShadow: isDark ? [
                  BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 4),
                ] : [],
              ),
              child: Stack(
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: (targetScore / 100).clamp(0.0, 1.0)),
                    duration: const Duration(milliseconds: 1200),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      return Container(
                        width: constraints.maxWidth * value,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4.r),
                          gradient: LinearGradient(
                            colors: [color.withOpacity(0.6), color],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          boxShadow: [
                            BoxShadow(color: color.withOpacity(0.4), blurRadius: 8, spreadRadius: 0),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ],
    ),
  );
}

Widget _buildRecommendationItem(String text, bool isDark) {
  return Padding(
    padding: EdgeInsets.only(bottom: 12.h),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: EdgeInsets.only(top: 2.h),
          padding: EdgeInsets.all(4.r),
          decoration: BoxDecoration(
            color: const Color(0xFFFFC107).withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.keyboard_arrow_right_rounded, size: 14.r, color: const Color(0xFFFFC107)),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white.withOpacity(0.85) : Colors.black87,
              height: 1.4,
            ),
          ),
        ),
      ],
    ),
  );
}