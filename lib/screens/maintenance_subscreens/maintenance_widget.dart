import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:persistent_bottom_nav_bar/persistent_bottom_nav_bar.dart';
import 'package:raxxy/providers/vehicle_provider.dart';
import 'package:raxxy/screens/dashboard_screen.dart';
import '../../providers/provider.dart';
import '../../services/maintenance_service.dart';
import 'chat_bot_screen.dart';

Widget maintenanceLogWidget(BuildContext context, VoidCallback rebuild) {
  final mileageController = TextEditingController();
  final theme = Theme.of(context);
  final isLight = theme.brightness == Brightness.light;

  return Container(
    height: 260.h,
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
              final vehicles = ref.watch(vehiclesProvider);

              return vehicles.when(
                data: (list) {
                  if (list.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.commute_outlined,
                              size: 40.sp, color: theme.disabledColor),
                          SizedBox(height: 8.h),
                          Text(
                            "No vehicles added",
                            style: TextStyle(
                              color: theme.disabledColor,
                              fontSize: 16.sp,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final services = <Map<String, dynamic>>[];

                  for (int i = 0; i < list.length; i++) {
                    var v = list[i];
                    final serv = MaintenanceService.getMaintenanceStatusForVehicle(
                      vehicle: v,
                    );
                    services.addAll(serv);
                  }

                  if (services.isEmpty) {
                    return Center(
                      child: Text(
                        "No Pending Services",
                        style: TextStyle(
                          color: theme.disabledColor,
                          fontSize: 16.sp,
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: services.length,
                    padding: EdgeInsets.symmetric(horizontal: 2.w),
                    separatorBuilder: (context, index) => SizedBox(width: 12.w),
                    itemBuilder: (context, index) {
                      final s = services[index];
                      final remaining = s["remaining"];

                      // Determine status style
                      Color statusColor;
                      IconData statusIcon;

                      if (remaining <= 0) {
                        statusColor = const Color(0xffef4444); // Red
                        statusIcon = Icons.warning_amber_rounded;
                      } else if (remaining <= 50) {
                        statusColor = const Color(0xfff97316); // Orange
                        statusIcon = Icons.priority_high_rounded;
                      } else {
                        statusColor = const Color(0xff22c55e); // Green
                        statusIcon = Icons.check_circle_outline_rounded;
                      }

                      return InkWell(
                        onTap: () async {
                          // Existing update logic
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text("Update Maintenance Event?"),
                              content: const Text("How do you want to update the Event?"),
                              actions: [
                                ElevatedButton(
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text("Enter mileage at the time of Event"),
                                        content: TextField(
                                          controller: mileageController,
                                          keyboardType: TextInputType.number,
                                          decoration: const InputDecoration(hintText: "Enter mileage"),
                                        ),
                                        actions: [
                                          ElevatedButton(
                                            onPressed: () {
                                              MaintenanceService().updateMaintenaceState(
                                                  s["vehicleId"], ref, double.parse(mileageController.text.trim()), s["title"]);
                                              rebuild();
                                              Navigator.of(ctx).pop(true);
                                            },
                                            child: const Text("Okay"),
                                          ),
                                        ],
                                      ),
                                    );
                                    Navigator.of(ctx).pop(true);
                                  },
                                  child: const Text("Enter mileage manually"),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    final distance = (s["distance"] as num).toDouble();
                                    MaintenanceService().updateMaintenaceState(s['vehicleId'], ref, distance, s["title"]);
                                    rebuild();
                                    Navigator.of(ctx).pop(true);
                                  },
                                  child: const Text("Use current mileage"),
                                ),
                              ],
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(20.r),
                        child: Container(
                          width: 200.w, // Fixed width for horizontal items
                          decoration: BoxDecoration(
                            color: isLight
                                ? statusColor.withOpacity(0.08)
                                : statusColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20.r),
                            border: Border.all(
                              color: statusColor.withOpacity(0.5),
                              width: 1.5,
                            ),
                          ),
                          padding: EdgeInsets.all(16.r),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          "${s["name"]}",
                                          style: TextStyle(
                                            fontSize: 14.sp,
                                            fontWeight: FontWeight.w600,
                                            color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Icon(statusIcon, color: statusColor, size: 22.sp),
                                    ],
                                  ),
                                  SizedBox(height: 6.h),
                                  Text(
                                    "${s["title"]}",
                                    style: TextStyle(
                                      fontSize: 18.sp,
                                      fontWeight: FontWeight.bold,
                                      color: theme.textTheme.bodyLarge?.color,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                              Container(
                                width: double.infinity,
                                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                                decoration: BoxDecoration(
                                  color: theme.cardColor.withOpacity(0.6),
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Remaining",
                                      style: TextStyle(
                                        fontSize: 10.sp,
                                        color: theme.textTheme.bodySmall?.color,
                                      ),
                                    ),
                                    Text(
                                      "${remaining.toStringAsFixed(0)} km",
                                      style: TextStyle(
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.w900,
                                        color: statusColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text("Error: $e")),
              );
            },
          ),
        ),
      ],
    ),
  );
}
Widget chatbotCardWidget(BuildContext context) {
  return Container(
    height: 120.h,
    width: MediaQuery.of(context).size.width - 40,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xff6366f1), Color(0xff8b5cf6)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(30.r),
      boxShadow: [
        BoxShadow(
          color: Colors. black.withOpacity(0.3),
          blurRadius: 4,
          spreadRadius: 3,
        ),
      ],
    ),
    child: InkWell(
      onTap: () {
        Navigator. push(
          context,
          MaterialPageRoute(builder: (context) => const ChatBotScreen()),
        );
      },
      child:  Padding(
        padding: EdgeInsets.all(20.r),
        child: Row(
          children: [
            Container(
              height: 60.h,
              width: 60.w,
              decoration: BoxDecoration(
                color: Colors.white. withOpacity(0.2),
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Icon(
                Icons. chat_bubble_outline,
                color: Colors.white,
                size: 35.sp,
              ),
            ),
            SizedBox(width: 20.w),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "AI Assistant",
                    style: TextStyle(
                      color: Colors. white,
                      fontSize: 22.sp,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 5.h),
                  Text(
                    "Ask me anything about vehicle",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.white,
              size: 20.sp,
            ),
          ],
        ),
      ),
    ),
  );
}