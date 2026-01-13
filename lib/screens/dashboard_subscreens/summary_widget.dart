import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:raxxy/providers/vehicle_provider.dart';
import '../../providers/summary_provider.dart';
import '../../services/maintenance_service.dart';

Widget summaryWidget(BuildContext context, VoidCallback rebuild) {
  return Container(
    height: 300.h,
    width: MediaQuery.of(context).size.width - 40,
    decoration: BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(30.r),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.3),
          blurRadius: 4,
          spreadRadius: 3,
        ),
      ],
    ),
    padding: EdgeInsets.all(12.r),
    child: Consumer(
      builder: (context, ref, _) {
        final summaries = ref.watch(summaryProvider);

        return summaries.when(
          data: (list) {
            if (list. isEmpty) {
              return const Center(child: Text("No Recorded Summaries"));
            }

            return ListView.builder(
              itemCount: list.length,
              itemBuilder: (context, index) {
                final sum = list[index];

                return Padding(
                  padding: const EdgeInsets.fromLTRB(0, 0, 0, 10).r,
                  child: Container(
                    width: MediaQuery.of(context).size.width - 60,
                    decoration: BoxDecoration(
                      color: (Theme.of(context).brightness == Brightness.light)
                          ? Color(0xFFCFD3EA)
                          : Color(0xFF363E50),
                      borderRadius: BorderRadius.circular(30.r),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(16.r),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header
                          Center(
                            child: Column(
                              children: [
                                Text(
                                  "Session Summary",
                                  style: TextStyle(
                                    fontSize: 22.sp,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  "${(sum["endTime"] as Timestamp).toDate()}",
                                  style: TextStyle(
                                    fontSize:  16.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 16.h),

                          // Duration & Time Breakdown
                          _buildSectionHeader("⏱️ Duration & Time", context),
                          _buildDataRow("Duration (min)", "${sum["durationMinutes"]}", context),
                          _buildDataRow("Duration (sec)", "${sum["durationSeconds"]}", context),
                          _buildDataRow("Stopped Time", "${sum["stoppedTimeSeconds"]}s", context),
                          _buildDataRow("Slow Time", "${sum["slowTimeSeconds"]}s", context),
                          _buildDataRow("Moderate Time", "${sum["moderateTimeSeconds"]}s", context),
                          _buildDataRow("Fast Time", "${sum["fastTimeSeconds"]}s", context),

                          SizedBox(height: 12.h),

                          // Distance & Speed
                          _buildSectionHeader("🚗 Distance & Speed", context),
                          _buildDataRow("Distance", "${(sum["distanceKm"] as num).toStringAsFixed(2)} km", context),
                          _buildDataRow("Avg Speed", "${(sum["avgSpeedKmh"] as num).toStringAsFixed(2)} km/h", context),
                          _buildDataRow("Max Speed", "${(sum["maxSpeedKmh"] as num).toStringAsFixed(2)} km/h", context),
                          _buildDataRow("Min Speed", "${(sum["minSpeedKmh"] as num).toStringAsFixed(2)} km/h", context),

                          SizedBox(height: 12.h),

                          // Harsh Events
                          _buildSectionHeader("⚠️ Harsh Events", context),
                          _buildDataRow("Harsh Accelerations", "${sum["harshAccelerations"]}", context),
                          _buildDataRow("Harsh Brakes", "${sum["harshBrakes"]}", context),
                          _buildDataRow("Total Harsh Events", "${sum["totalHarshEvents"]}", context),
                          _buildDataRow("Harsh Events/Min", "${sum["harshEventsPerMinute"]}", context),

                          SizedBox(height:  12.h),

                          // Turns
                          _buildSectionHeader("↩️ Turns", context),
                          _buildDataRow("Left Turns", "${sum["leftTurns"]}", context),
                          _buildDataRow("Right Turns", "${sum["rightTurns"]}", context),
                          _buildDataRow("Total Turns", "${sum["totalTurns"]}", context),
                          _buildDataRow("Turns/Min", "${sum["turnsPerMinute"]}", context),

                          SizedBox(height: 12.h),

                          // Switches
                          _buildSectionHeader("🔄 Accel/Decel Switches", context),
                          _buildDataRow("Accel to Decel", "${sum["accelToDecelSwitches"]}", context),
                          _buildDataRow("Decel to Accel", "${sum["decelToAccelSwitches"]}", context),
                          _buildDataRow("Total Switches", "${sum["totalSwitches"]}", context),
                          _buildDataRow("Switches/Min", "${sum["switchesPerMinute"]}", context),

                          SizedBox(height: 12.h),

                          // Driving Type Probability
                          _buildSectionHeader("🛣️ Driving Type", context),
                          _buildProbabilityRow(
                              "City Driving",
                              (sum["cityProbability"] as num).toDouble(),
                              context
                          ),
                          _buildProbabilityRow(
                              "Highway Driving",
                              (sum["highwayProbability"] as num).toDouble(),
                              context
                          ),

                          SizedBox(height:  12.h),

                          // Timestamps
                          _buildSectionHeader("📅 Session Times", context),
                          _buildDataRow(
                              "Start Time",
                              "${(sum["startTime"] as Timestamp).toDate()}",
                              context,
                              smallFont: true
                          ),
                          _buildDataRow(
                              "End Time",
                              "${(sum["endTime"] as Timestamp).toDate()}",
                              context,
                              smallFont: true
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
          loading: () => const Center(child:  CircularProgressIndicator()),
          error: (e, _) => Center(child: Text("Error:  $e")),
        );
      },
    ),
  );
}

// Helper widget for section headers
Widget _buildSectionHeader(String title, BuildContext context) {
  return Padding(
    padding: EdgeInsets.only(bottom: 8.h),
    child: Text(
      title,
      style: TextStyle(
        fontSize:  18.sp,
        fontWeight: FontWeight.w800,
        color: Theme.of(context).brightness == Brightness. light
            ? Colors.blueAccent
            : Colors.lightBlueAccent,
      ),
    ),
  );
}

// Helper widget for data rows
Widget _buildDataRow(String label, String value, BuildContext context, {bool smallFont = false}) {
  return Padding(
    padding:  EdgeInsets.symmetric(vertical: 2.h),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children:  [
        Text(
          label,
          style: TextStyle(
            fontSize: smallFont ? 12.sp : 14.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style:  TextStyle(
            fontSize: smallFont ? 12.sp : 14.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

// Helper widget for probability rows with progress bar
Widget _buildProbabilityRow(String label, double probability, BuildContext context) {
  return Padding(
    padding:  EdgeInsets.symmetric(vertical: 4.h),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize:  14.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              "${(probability * 100).toStringAsFixed(1)}%",
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        SizedBox(height: 4.h),
        ClipRRect(
          borderRadius: BorderRadius.circular(4.r),
          child: LinearProgressIndicator(
            value:  probability,
            minHeight: 6.h,
            backgroundColor: Colors.grey. withOpacity(0.3),
            valueColor: AlwaysStoppedAnimation<Color>(
              probability > 0.5 ? Colors.green : Colors. orange,
            ),
          ),
        ),
      ],
    ),
  );
}