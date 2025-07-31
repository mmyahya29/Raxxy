import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../providers/provider.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final auth = ref.read(firebaseAuthProvider);
    final userEmail = auth.currentUser?.email ?? 'No email';

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
              SizedBox(height: 10.h),
              Container(
                height: 120.h,
                width: MediaQuery.of(context).size.width - 40,
                decoration: BoxDecoration(
                  color: const Color(0xff00980e),
                  borderRadius: BorderRadius.circular(30.r),
                ),
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                child: Consumer(
                  builder: (context, ref, _) {
                    final monitor = ref.watch(vehicleMonitorProvider);

                    if (monitor.vehicleId == null) {
                      return Center(
                        child: Text(
                          'No currently active Vehicle',
                          style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w300),
                        ),
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${monitor.make ?? "Vehicle"} ${monitor.model ?? ""}',
                          style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w700),
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          'Speed: ${monitor.speed.toStringAsFixed(2)} km/h',
                          style: TextStyle(fontSize: 16.sp),
                        ),
                        Text(
                          'Acceleration: ${monitor.acceleration.toStringAsFixed(2)} m/s²',
                          style: TextStyle(fontSize: 16.sp),
                        ),
                        Text(
                          'Distance: ${monitor.distance.toStringAsFixed(2)} m',
                          style: TextStyle(fontSize: 16.sp),
                        ),
                      ],
                    );
                  },
                ),
              ),
              SizedBox(height: 10.h),
              Text(
                'Performance Metrics',
                style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 10.h),
            ],
          ),
        ),
      ),
    );
  }
}
