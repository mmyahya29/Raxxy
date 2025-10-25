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
            if (list.isEmpty) {
              return const Center(child: Text("No Recorded Summaries"));
            }

            return ListView.builder(
              itemCount: list.length,
              itemBuilder: (context, index) {
                final sum = list[index];

                return Padding(
                  padding: const EdgeInsets.fromLTRB(0, 0, 0, 10).r,
                  child: Container(
                    height: 150.h,
                    width: MediaQuery.of(context).size.width - 60,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCFD3EA),
                      borderRadius: BorderRadius.circular(30.r),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Session:",
                          style: TextStyle(
                            fontSize: 20.sp,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          "${(sum["endTime"] as Timestamp).toDate()}",
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Duration:",
                                    style: TextStyle(
                                        fontSize: 18.sp,
                                        fontWeight: FontWeight.w500)),
                                Text("Total Distance Travelled:",
                                    style: TextStyle(
                                        fontSize: 18.sp,
                                        fontWeight: FontWeight.w500)),
                                Text("Harsh Throttle Events:",
                                    style: TextStyle(
                                        fontSize: 18.sp,
                                        fontWeight: FontWeight.w500)),
                                Text("Harsh Brake Events:",
                                    style: TextStyle(
                                        fontSize: 18.sp,
                                        fontWeight: FontWeight.w500)),
                              ],
                            ),
                            SizedBox(width: 10.w),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("${sum["duration"]}",
                                    style: TextStyle(
                                        fontSize: 18.sp,
                                        fontWeight: FontWeight.w500)),
                                Text(
                                    "${(sum["distanceKm"] as num).toStringAsFixed(2)}",
                                    style: TextStyle(
                                        fontSize: 18.sp,
                                        fontWeight: FontWeight.w500)),
                                Text("${sum["harshAccelerations"]}",
                                    style: TextStyle(
                                        fontSize: 18.sp,
                                        fontWeight: FontWeight.w500)),
                                Text("${sum["harshBrakes"]}",
                                    style: TextStyle(
                                        fontSize: 18.sp,
                                        fontWeight: FontWeight.w500)),
                              ],
                            )
                          ],
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
  );
}
