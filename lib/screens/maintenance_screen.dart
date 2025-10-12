import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:persistent_bottom_nav_bar/persistent_bottom_nav_bar.dart';
import 'maintenance_subscreens/maintenance_widget.dart';
import 'dashboard_subscreens/monitor_widget.dart';
import 'dashboard_subscreens/summary_widget.dart';

class MaintenanceScreen extends ConsumerStatefulWidget {
  final PersistentTabController controller;
  const MaintenanceScreen({super.key, required this.controller});

  @override
  ConsumerState<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends ConsumerState<MaintenanceScreen> {
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
