import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:raxxy/providers/goals_provider.dart';
import 'package:raxxy/providers/vehicle_provider.dart';
import '../../providers/summary_provider.dart';
import '../../services/maintenance_service.dart';

Widget goalsWidget(BuildContext context, VoidCallback rebuild){

  return Container(
    height: 300.h,
    width: MediaQuery.of(context).size.width - 40,
    clipBehavior: Clip.none,
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
        final goals = ref.watch(goalProvider);

        return goals.when(
          data: (list) {
            if (list.isEmpty) {
              return const Center(child: Text("No Currently Active Goals"));
            }
            return ListView.builder(
              itemCount: list.length,
              itemBuilder: (context, index) {
                final goal = list[index];

                return Padding(
                  padding: const EdgeInsets.fromLTRB(0,0,0,10).r,
                  child: Container(
                    height: 100.h,
                    width: MediaQuery
                        .of(context)
                        .size
                        .width - 60,
                    decoration: BoxDecoration(
                      color: (Theme.of(context).brightness == Brightness.light)?Color(
                          0xffe6cbe3):Color(0xff655565),
                      borderRadius: BorderRadius.circular(30.r),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 0.0).r,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("${goal["title"]}", style: TextStyle(
                              fontSize: 20.sp,
                              fontWeight: FontWeight.w900),),
                          Text("${goal["description"]}", style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w600),),
                          Text("${goal["target"]}", style: TextStyle(
                              fontSize: 16.sp,
                              color: Color(0xffff3f3f),
                              fontWeight: FontWeight.w600),),
                        ],
                      ),
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