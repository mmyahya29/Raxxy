import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:persistent_bottom_nav_bar/persistent_bottom_nav_bar.dart';
import 'package:raxxy/providers/vehicle_provider.dart';
import '../providers/provider.dart';
import '../services/maintenance_service.dart';
import 'dashboard_subscreens/maintenance_widget.dart';
import 'dashboard_subscreens/monitor_widget.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  final PersistentTabController controller;
  const DashboardScreen({super.key, required this.controller});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  Widget build(BuildContext context) {

    final mileageController = TextEditingController();

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0).r,
        child: SingleChildScrollView(
          child: Column(
            children: [
              SizedBox(height: 10.h),
              Text(
                'Currently Active Vehicle',
                style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 5.h),
              monitorWidget(context,widget),
              SizedBox(height: 10.h,),
              Text(
                'Maintenance Logs',
                style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 5.h,),
              maintenanceLogWidget(context, () => setState(() {})),

            ],
          ),
        ),
      ),
    );
  }
}
