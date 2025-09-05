import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:persistent_bottom_nav_bar/persistent_bottom_nav_bar.dart';
import 'package:raxxy/providers/vehicle_provider.dart';
import '../providers/provider.dart';
import '../services/maintenance_service.dart';
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
              Container(
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
                    final vehicles = ref.watch(vehiclesProvider);

                    return vehicles.when(
                      data: (list) {
                        if (list.isEmpty) {
                          return const Center(child: Text("No vehicles added"));
                        }

                        final services = <Map<String, dynamic>>[];

                        for(int i=0;i<list.length;i++){
                          var v = list[i];
                          final serv = MaintenanceService.getMaintenanceStatusForVehicle(vehicle: v);
                          services.addAll(serv);
                        }

                        if(services.isNotEmpty){
                          return ListView.builder(
                            itemCount: services.length,
                            itemBuilder: (context, index) {
                              final s = services[index];

                              Color bgColor;
                              if (s["remaining"] <= 0) {
                                bgColor = Color(0xffba0000);
                              } else if (s["remaining"] <= 50) {
                                bgColor = Color(0xffca3800);
                              } else {
                                bgColor = Color(0xff44ac00);
                              }

                              return Padding(
                                padding: const EdgeInsets.fromLTRB(0,0,0,10).r,
                                child: InkWell(
                                //   onTap: () async {
                                //     MaintenanceService().updateOilChange(v, ref, distance)
                                // },
                                  child: Container(
                                    height: 80.h,
                                    width: MediaQuery
                                        .of(context)
                                        .size
                                        .width - 60,
                                    decoration: BoxDecoration(
                                      color: bgColor,
                                      borderRadius: BorderRadius.circular(30.r),
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text("${s["name"]}", style: TextStyle(
                                            fontSize: 22.sp,
                                            fontWeight: FontWeight.w900),),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                          children: [
                                            Text("${s["title"]}", style: TextStyle(
                                                fontSize: 18.sp,
                                                fontWeight: FontWeight.w500),),
                                            Text("Remaining: ${s["remaining"].toStringAsFixed(2)} KM", style: TextStyle(
                                                fontSize: 18.sp,
                                                fontWeight: FontWeight.w500),)
                                          ],
                                        )
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        }
                        return const Center(child: Text("No Currently Pending Services"));
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(child: Text("Error: $e")),
                    );
                  },
                ),
              ),

            ],
          ),
        ),
      ),
    );
  }
}
