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

Widget maintenanceLogWidget(BuildContext context, VoidCallback rebuild){

  final mileageController = TextEditingController();

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
                    bgColor = Color(0xfc910505);
                  } else if (s["remaining"] <= 50) {
                    bgColor = Color(0xffca4918);
                  } else {
                    bgColor = Color(0xff6ed826);
                  }

                  return Padding(
                    padding: const EdgeInsets.fromLTRB(0,0,0,10).r,
                    child: InkWell(
                      onTap: () async {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text(
                                "Update Maintenance Event?"),
                            content: Text("How do u want to update the Event?"),
                            actions: [
                              ElevatedButton(
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text(
                                          "Enter mileage at the time of Event"),
                                      content: TextField(
                                        controller:
                                        mileageController,
                                        keyboardType:
                                        TextInputType.number,
                                        decoration:
                                        const InputDecoration(
                                          hintText: "Enter mileage",
                                        ),
                                      ),
                                      actions: [
                                        ElevatedButton(
                                          onPressed: () {
                                            MaintenanceService().updateMaintenaceState(s["vehicleId"], ref, double.parse(mileageController.text.trim()), s["title"]);
                                            rebuild();
                                            Navigator.of(ctx)
                                                .pop(true);
                                          },
                                          child: const Text("Okay"),
                                        ),
                                      ],
                                    ),
                                  );
                                  MaintenanceService().updateMaintenaceState(s["vehicleId"], ref, double.parse(mileageController.text.trim()), s["title"]);
                                  rebuild();
                                  Navigator.of(ctx)
                                      .pop(true);
                                },
                                child: const Text("Enter mileage at the time of Event"),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  MaintenanceService().updateMaintenaceState(s['vehicleId'], ref, s["distance"], s["title"]);
                                  rebuild();
                                  Navigator.of(ctx)
                                      .pop(true);
                                },
                                child: const Text("Use current mileage"),
                              ),
                            ],
                          ),
                        );
                      },
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
                              color:Colors.white,
                                fontSize: 22.sp,
                                fontWeight: FontWeight.w900),),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Text("${s["title"]}", style: TextStyle(
                                    fontSize: 18.sp,
                                    fontWeight: FontWeight.w500, color:Colors.white,),),
                                Text("Remaining: ${s["remaining"].toStringAsFixed(2)} KM", style: TextStyle(
                                    fontSize: 18.sp,
                                    fontWeight: FontWeight.w500, color:Colors.white,),)
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
  );
}