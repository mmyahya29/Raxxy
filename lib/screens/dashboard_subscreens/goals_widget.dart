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
  final isLight = theme.brightness == Brightness.light;

  return Container(
    height: 260.h, // Adjusted height for better horizontal proportions
    width: double.infinity,
    decoration: BoxDecoration(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(24.r),
      boxShadow: [
        BoxShadow(
          color: theme.shadowColor.withOpacity(0.1),
          blurRadius: 10,
          spreadRadius: 2,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 16.w),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Consumer(
            builder: (context, ref, _) {
              final goals = ref.watch(goalProvider);

              return goals.when(
                data: (list) {
                  if (list.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.flag_outlined,
                              size: 40.sp, color: theme.disabledColor),
                          SizedBox(height: 8.h),
                          Text(
                            "No Currently Active Goals",
                            style: TextStyle(
                              color: theme.disabledColor,
                              fontSize: 16.sp,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    scrollDirection: Axis.horizontal, // Horizontal scrolling
                    itemCount: list.length,
                    padding: EdgeInsets.symmetric(horizontal: 2.w),
                    separatorBuilder: (context, index) => SizedBox(width: 12.w),
                    itemBuilder: (context, index) {
                      final goal = list[index];
                      final title = goal["title"] ?? "Untitled";
                      final description = goal["description"] ?? "";
                      final target = goal["target"] ?? "";

                      return Container(
                        width: 240.w, // Fixed width prevents layout issues
                        decoration: BoxDecoration(
                          color: isLight
                              ? const Color(0xfff5f0f5)
                              : const Color(0xff4a404a),
                          borderRadius: BorderRadius.circular(20.r),
                          border: Border.all(
                            color: isLight
                                ? Colors.grey.shade200
                                : Colors.white10,
                          ),
                        ),
                        padding: EdgeInsets.all(16.r),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Expanded(
                              // Expanded here forces text to wrap/ellipsis
                              // preventing the 11px overflow
                              child: Text(
                                "$title",
                                style: TextStyle(
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.bold,
                                  color: theme.textTheme.bodyLarge?.color,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (target.toString().isNotEmpty) ...[
                              SizedBox(width: 8.w),
                              Container(
                                width: 220.h,
                                padding: EdgeInsets.symmetric(
                                    horizontal: 8.w,
                                    vertical: 4.h
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xffff3f3f).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                child: Text(
                                  "$target",
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    color: const Color(0xffff3f3f),
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                            if (description.toString().isNotEmpty) ...[
                              SizedBox(height: 12.h),
                              Expanded(
                                child: Text(
                                  "$description",
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 4,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text("Error loading goals")),
              );
            },
          ),
        ),
      ],
    ),
  );
}