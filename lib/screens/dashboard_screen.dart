import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:persistent_bottom_nav_bar/persistent_bottom_nav_bar.dart';
import '../providers/provider.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  final PersistentTabController controller;
  const DashboardScreen({super.key, required this.controller});

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
              SizedBox(height: 5.h),
              Container(
                height: 390.h,
                width: MediaQuery.of(context).size.width - 40,
                decoration: BoxDecoration(
                  color: const Color(0xff292929),
                  borderRadius: BorderRadius.circular(30.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 4,
                      spreadRadius: 3,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    SizedBox(height: 10.h),
                    InkWell(
                      onTap: (){
                        widget.controller.jumpToTab(1);
                      },
                      child: Container(
                        height: 120.h,
                        width: MediaQuery.of(context).size.width - 60,
                        decoration: BoxDecoration(
                          color: const Color(0xff007e0f),
                          borderRadius: BorderRadius.circular(30.r),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 4,
                              spreadRadius: 3,
                            ),
                          ],
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
                    ),
                    SizedBox(height: 10.h),
                    Text(
                      'Performance Metrics',
                      style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 10.h),
                    Container(
                      height: 200.h,
                      width: MediaQuery.of(context).size.width - 60,
                      decoration: BoxDecoration(
                        color: const Color(0xff332d85),
                        borderRadius: BorderRadius.circular(30.r),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 4,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                      padding: EdgeInsets.all(16.r),
                      child: MetricsGraph(),
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget MetricsGraph(){
    return Consumer(
      builder: (context, ref, _) {
        final monitor = ref.watch(vehicleMonitorProvider);
        final speedData = monitor.speedHistory;
        final accData = monitor.accelerationHistory;

        if (speedData.isEmpty && accData.isEmpty) {
          return const Center(child: Text("No speed or acceleration data yet", style: TextStyle(color: Colors.white)));
        }

        final maxY = [
          ...speedData,
          ...accData,
        ].fold<double>(0.0, (prev, val) => val > prev ? val : prev);

        return LineChart(
          LineChartData(
            minX: 0,
            maxX: (speedData.length > accData.length ? speedData.length : accData.length).toDouble() - 1,
            minY: 0,
            maxY: (maxY + 5).clamp(0, 100), // Prevent overflow

            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  interval: 10,
                  getTitlesWidget: (value, _) => Text('${value.toInt()}', style: TextStyle(color: Colors.white, fontSize: 10.sp)),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 1,
                  getTitlesWidget: (value, _) => Text('${value.toInt()}', style: TextStyle(color: Colors.white, fontSize: 10.sp)),
                ),
              ),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),

            gridData: FlGridData(
              show: true,
              drawVerticalLine: true,
              horizontalInterval: 10,
              verticalInterval: 1,
              getDrawingHorizontalLine: (_) => FlLine(color: Colors.white12, strokeWidth: 1),
              getDrawingVerticalLine: (_) => FlLine(color: Colors.white12, strokeWidth: 1),
            ),

            borderData: FlBorderData(
              show: true,
              border: Border.all(color: Colors.white24, width: 1),
            ),

            lineBarsData: [
              LineChartBarData(
                spots: List.generate(
                  speedData.length,
                      (i) => FlSpot(i.toDouble(), speedData[i]),
                ),
                isCurved: true,
                color: Colors.greenAccent,
                barWidth: 2,
                dotData: FlDotData(show: false),
                belowBarData: BarAreaData(show: false),
              ),
              LineChartBarData(
                spots: List.generate(
                  accData.length,
                      (i) => FlSpot(i.toDouble(), accData[i]),
                ),
                isCurved: true,
                color: Colors.redAccent,
                barWidth: 2,
                dotData: FlDotData(show: false),
                belowBarData: BarAreaData(show: false),
              ),
            ],
          ),
        );
      },
    );
  }
}
