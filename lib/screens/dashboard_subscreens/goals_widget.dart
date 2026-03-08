import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:raxxy/providers/goals_provider.dart';
import 'package:raxxy/providers/vehicle_provider.dart';
import '../../providers/summary_provider.dart';
import '../../services/maintenance_service.dart';

Widget goalsWidget(BuildContext context, VoidCallback rebuild) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;

  return Container(
    height: 260.h,
    width: double.infinity,
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
    padding: EdgeInsets.only(top: 20.h, bottom: 15.h),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // HUD Header
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          child: Row(
            children: [
              Icon(Icons.track_changes_rounded, color: const Color(0xFFFF9800), size: 20.r),
              SizedBox(width: 8.w),
              Text(
                'ACTIVE DIRECTIVES',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFFFF9800),
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 15.h),

        // Goals List
        Expanded(
          child: Consumer(
            builder: (context, ref, _) {
              final goals = ref.watch(goalProvider);

              return goals.when(
                data: (list) {
                  if (list.isEmpty) {
                    return _buildEmptyGoalsState(isDark);
                  }

                  return ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    scrollDirection: Axis.horizontal,
                    itemCount: list.length,
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    separatorBuilder: (context, index) => SizedBox(width: 15.w),
                    itemBuilder: (context, index) {
                      final goal = list[index];
                      // Alternate accent colors for visual variety in the list
                      final accentColor = index % 2 == 0 ? const Color(0xFFFF9800) : const Color(0xFF00E5FF);

                      return _buildGoalCard(goal.data(), accentColor, isDark);
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFFF9800))),
                error: (e, _) => Center(child: Text("System Error: $e", style: const TextStyle(color: Colors.redAccent))),
              );
            },
          ),
        ),
      ],
    ),
  );
}

Widget _buildEmptyGoalsState(bool isDark) {
  return Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.flag_circle_outlined,
          size: 45.sp,
          color: isDark ? Colors.white24 : Colors.grey.withOpacity(0.5),
        ),
        SizedBox(height: 12.h),
        Text(
          "NO ACTIVE TARGETS",
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

Widget _buildGoalCard(Map<String, dynamic> goal, Color accentColor, bool isDark) {
  final title = goal["title"]?.toString() ?? "UNTITLED DIRECTIVE";
  final description = goal["description"]?.toString() ?? "";
  final target = goal["target"]?.toString() ?? "";

  return Container(
    width: 260.w,
    decoration: BoxDecoration(
      color: isDark ? accentColor.withOpacity(0.05) : accentColor.withOpacity(0.03),
      borderRadius: BorderRadius.circular(24.r),
      border: Border.all(color: accentColor.withOpacity(0.3), width: 1.5),
      boxShadow: [
        BoxShadow(color: accentColor.withOpacity(0.05), blurRadius: 10, spreadRadius: 1),
      ],
    ),
    padding: EdgeInsets.all(18.r),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title & Target Row
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              flex: 3,
              child: Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : Colors.black87,
                  height: 1.2,
                  letterSpacing: 0.5,
                ),
                maxLines: 3, // Allow title to use multiple lines if needed
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (target.isNotEmpty) ...[
              SizedBox(width: 10.w),
              Flexible(
                flex: 2, // Limits the max width, but allows it to be smaller
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: accentColor.withOpacity(0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min, // Hugs content if text is short
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(top: 2.h), // Align icon with text visually
                        child: Icon(Icons.ads_click_rounded, color: accentColor, size: 12.r),
                      ),
                      SizedBox(width: 4.w),
                      Flexible( // Allows text to wrap cleanly to the next line
                        child: Text(
                          target.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10.sp,
                            color: accentColor,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                          // No maxLines here! It will wrap naturally.
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        SizedBox(height: 12.h),

        // Divider
        Container(
          height: 1,
          width: double.infinity,
          color: accentColor.withOpacity(0.2),
        ),
        SizedBox(height: 12.h),

        // Description - Wrapped in ScrollView to manage remaining vertical space safely
        if (description.isNotEmpty)
          Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Text(
                description,
                style: TextStyle(
                  fontSize: 13.sp,
                  color: isDark ? Colors.white70 : Colors.black54,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
            ),
          )
        else
          Flexible(
            child: Center(
              child: Text(
                "No additional parameters defined.",
                style: TextStyle(
                  fontSize: 12.sp,
                  color: isDark ? Colors.white30 : Colors.black26,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ),
      ],
    ),
  );
}