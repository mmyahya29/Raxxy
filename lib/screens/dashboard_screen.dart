import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:persistent_bottom_nav_bar/persistent_bottom_nav_bar.dart';
import 'package:raxxy/providers/vehicle_provider.dart';
import 'package:raxxy/screens/dashboard_subscreens/goals_widget.dart';
import '../providers/goals_provider.dart';
import '../providers/provider.dart';
import '../services/maintenance_service.dart';
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

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0).r,
        child: SingleChildScrollView(
          child: Column(
            children: [
              SizedBox(height: 10.h),
              Container(
                height: 50.h,
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
                child: Consumer(
                  builder: (context, ref, _) {
                    final driveScore = ref.watch(driveScoreProvider);

                    return driveScore.when(
                      data: (score) => Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.star, size: 30.r,color: Colors.amber,),
                          SizedBox(width: 10.w,),
                          Text(
                            "Driving Score: ${score?.toStringAsFixed(1) ?? 'N/A'}",
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      loading: () => const CircularProgressIndicator(),
                      error: (e, _) => Text("Error: $e"),
                    );
                  },
                ),
              ),
              SizedBox(height: 10.h),
              Text(
                'Currently Active Vehicle',
                style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 5.h),
              monitorWidget(context,widget),
              SizedBox(height: 10.h,),
              Text(
                'Summaries',
                style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 5.h,),
              summaryWidget(context, () => setState(() {})),
              SizedBox(height: 10.h,),
              Text(
                'Active Goals',
                style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 5.h,),
              goalsWidget(context, () => setState(() {})),
            ],
          ),
        ),
      ),
    );
  }
}
