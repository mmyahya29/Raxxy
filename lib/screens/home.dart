import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:persistent_bottom_nav_bar/persistent_bottom_nav_bar.dart';
import '../providers/provider.dart';
import '../services/vehicle_monitor_service.dart';
import 'add_vehicle.dart';

class HomePage extends ConsumerStatefulWidget {
  final PersistentTabController controller;
  const HomePage({super.key, required this.controller});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int? expandedIndex;
  String? monitoringVehicleId; // Track which vehicle is being monitored

  @override
  Widget build(BuildContext context) {
    final auth = ref.read(firebaseAuthProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('What are we Driving today?'),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20).r,
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder(
                stream: ref.read(firestoreProvider)
                    .collection('users')
                    .doc(auth.currentUser?.uid)
                    .collection('vehicles')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(child: Text('No current vehicles'));
                  }

                  final vehicles = snapshot.data!.docs;

                  return ListView.builder(
                    itemCount: vehicles.length,
                    itemBuilder: (context, index) {
                      final vehicle = vehicles[index];
                      final isExpanded = expandedIndex == index;
                      final isMonitoring = monitoringVehicleId == vehicle.id;

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            expandedIndex = isExpanded ? null : index;
                          });
                        },
                        child: AnimatedContainer(
                          duration: Duration(milliseconds: 500),
                          curve: Curves.easeInOut,
                          margin: EdgeInsets.symmetric(vertical: 8.h),
                          padding: EdgeInsets.all(12.w),
                          decoration: BoxDecoration(
                            color: Color(0xff202020),
                            borderRadius: BorderRadius.circular(20.r),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    (vehicle['type'] == 'car' || vehicle['type'] == 'Car')
                                        ? Icons.directions_car_filled_rounded
                                        : Icons.directions_bike_rounded,
                                    size: 30.r,
                                  ),
                                  SizedBox(width: 16.w),
                                  Text(
                                    '${vehicle['make']} ${vehicle['model']}',
                                    style: TextStyle(
                                      fontSize: 20.sp,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              AnimatedSize(
                                duration: Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                                child: isExpanded
                                    ? Padding(
                                  padding: EdgeInsets.only(top: 10.h),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(height: 10.h),
                                      Text('Type: ${vehicle['type']}'),
                                      Text('Year: ${vehicle['year']}'),
                                      Text('Mileage: ${vehicle['mileage'].toStringAsFixed(2)} km'),
                                      SizedBox(height: 10.h),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                        children: [
                                          ElevatedButton(
                                            onPressed: () async {
                                              await ref.read(firestoreProvider)
                                                  .collection('users')
                                                  .doc(auth.currentUser?.uid)
                                                  .collection('vehicles')
                                                  .doc(vehicle.id)
                                                  .delete();

                                              // If the deleted vehicle is being monitored, stop monitoring
                                              if (monitoringVehicleId == vehicle.id) {
                                                VehicleMonitorService().stopMonitoring(ref);
                                                monitoringVehicleId = null;
                                              }

                                              setState(() {});
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red,
                                            ),
                                            child: Text('Delete', style: TextStyle(color: Colors.white)),
                                          ),
                                          ElevatedButton(
                                            onPressed: () async {
                                              if (isMonitoring) {
                                                VehicleMonitorService().stopMonitoring(ref);
                                                monitoringVehicleId = null;
                                              } else {
                                                showDialog(
                                                  context: context,
                                                  builder: (ctx) => AlertDialog(
                                                    title: const Text("Starting to drive?"),
                                                    content: const Text("Make sure to set your device on the dashboard of your car or on a phone stand of your Bike for better accuracy, Otherwise you might experience crappy monitoring..."),
                                                    actions: [
                                                      ElevatedButton(
                                                        onPressed: () => Navigator.of(ctx).pop(true),
                                                        child: const Text("Okay"),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                                await VehicleMonitorService().startMonitoring(
                                                  userId: auth.currentUser!.uid,
                                                  vehicleId: vehicle.id,
                                                  make: vehicle['make'],
                                                  model: vehicle['model'],
                                                  ref: ref
                                                );
                                                monitoringVehicleId = vehicle.id;
                                              }
                                              setState(() {});
                                              setState(() {});
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: isMonitoring ? Colors.orange : Colors.green,
                                            ),
                                            child: Text(
                                              isMonitoring ? 'Stop' : 'Start',
                                              style: TextStyle(color: Colors.white),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                )
                                    : SizedBox.shrink(),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            SizedBox(height: 10.h),
            SizedBox(
              height: 50.h,
              width: MediaQuery.of(context).size.width - 40,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddVehicleScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff6259ff),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20.0),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Add a New Vehicle',
                      style: TextStyle(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w500,
                        color: Color(0xffffffff),
                      ),
                    ),
                    SizedBox(width: 5.w),
                    Icon(Icons.add_circle, size: 30.r, color: Color(0xffffffff)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
