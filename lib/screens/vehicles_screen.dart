import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:persistent_bottom_nav_bar/persistent_bottom_nav_bar.dart';
import 'package:raxxy/widgets/reusable_widgets.dart';
import '../providers/provider.dart';
import '../providers/vehicle_provider.dart';
import '../services/vehicle_monitor_service.dart';
import 'vehicle_subscreens/add_vehicle.dart';
import 'package:geolocator/geolocator.dart';

class VehiclesScreen extends ConsumerStatefulWidget {
  final PersistentTabController controller;
  const VehiclesScreen({super.key, required this.controller});

  @override
  ConsumerState<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends ConsumerState<VehiclesScreen> {
  int? expandedIndex;
  String? monitoringVehicleId; // Track which vehicle is being monitored

  @override
  void initState() {
    super.initState();
    _initPermissionsAndStart();
  }

  Future<void> _initPermissionsAndStart() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // prompt user to enable GPS
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // cannot proceed
        return;
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.read(firebaseAuthProvider);
    final mileageController = TextEditingController();

    return Scaffold(
      appBar: AppBar(
        title: const Text('What are we Driving today?'),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20).r,
        child: Column(
          children: [
            Expanded(
              child: Consumer(
                builder: (context, ref, _) {
                  final vehiclesAsync = ref.watch(vehiclesProvider);

                  return vehiclesAsync.when(
                    data: (vehicles) {
                      if (vehicles.isEmpty) {
                        return const Center(child: Text('No current vehicles'));
                      }

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
                              duration: const Duration(milliseconds: 500),
                              curve: Curves.easeInOut,
                              margin: EdgeInsets.symmetric(vertical: 8.h),
                              padding: EdgeInsets.all(12.w),
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(20.r),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 4,
                                    spreadRadius: 3,
                                  ),
                                ],
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
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                    child: isExpanded
                                        ? Padding(
                                      padding: EdgeInsets.only(top: 10.h),
                                      child: Column(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                        children: [
                                          SizedBox(height: 10.h),
                                          Text('Type: ${vehicle['type']}'),
                                          Text('Year: ${vehicle['year']}'),
                                          Text(
                                            'Mileage: ${(vehicle['mileage'] as num).toDouble().toStringAsFixed(2)} km',
                                          ),
                                          SizedBox(height: 10.h),
                                          Row(
                                            mainAxisAlignment:
                                            MainAxisAlignment.spaceEvenly,
                                            children: [
                                              ElevatedButton(
                                                onPressed: () async {
                                                  await ref
                                                      .read(firestoreProvider)
                                                      .collection('users')
                                                      .doc(auth.currentUser?.uid)
                                                      .collection('vehicles')
                                                      .doc(vehicle.id)
                                                      .delete();

                                                  if (monitoringVehicleId ==
                                                      vehicle.id) {
                                                    showDialog(
                                                      context: context,
                                                      builder: (ctx) =>
                                                          AlertDialog(
                                                            title: const Text(
                                                                "Enter current mileage to cover up for hardware inaccuracies"),
                                                            content: TextField(
                                                              controller:
                                                              mileageController,
                                                              keyboardType:
                                                              TextInputType
                                                                  .number,
                                                              decoration:
                                                              const InputDecoration(
                                                                hintText:
                                                                "Enter mileage",
                                                              ),
                                                            ),
                                                            actions: [
                                                              ElevatedButton(
                                                                onPressed: () {
                                                                  VehicleMonitorService()
                                                                      .stopMonitoring(
                                                                    ref
                                                                  );
                                                                  monitoringVehicleId =
                                                                  null;
                                                                  setState(() {});
                                                                  Navigator.of(ctx)
                                                                      .pop(true);
                                                                },
                                                                child: const Text(
                                                                    "Okay"),
                                                              ),
                                                            ],
                                                          ),
                                                    );
                                                  }
                                                },
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.red,
                                                ),
                                                child: const Text(
                                                  'Delete',
                                                  style: TextStyle(
                                                      color: Colors.white),
                                                ),
                                              ),
                                              ElevatedButton(
                                                onPressed: () async {
                                                  if (isMonitoring) {
                                                    showDialog(
                                                      context: context,
                                                      builder: (ctx) =>
                                                          AlertDialog(
                                                            title: const Text(
                                                                "Enter current mileage to cover up for hardware inaccuracies"),
                                                            content: TextField(
                                                              controller:
                                                              mileageController,
                                                              keyboardType:
                                                              TextInputType
                                                                  .number,
                                                              decoration:
                                                              const InputDecoration(
                                                                hintText:
                                                                "Enter mileage",
                                                              ),
                                                            ),
                                                            actions: [
                                                              ElevatedButton(
                                                                onPressed: () {
                                                                  VehicleMonitorService()
                                                                      .stopMonitoring(
                                                                    ref,
                                                                  );
                                                                  monitoringVehicleId =
                                                                  null;
                                                                  setState(() {});
                                                                  Navigator.of(ctx)
                                                                      .pop(true);
                                                                },
                                                                child: const Text(
                                                                    "Okay"),
                                                              ),
                                                            ],
                                                          ),
                                                    );
                                                  } else {
                                                    showDialog(
                                                      context: context,
                                                      builder: (ctx) =>
                                                          AlertDialog(
                                                            title: const Text(
                                                                "Starting to drive?"),
                                                            content: const Text(
                                                                "Make sure to set your device on the dashboard of your car or on a phone stand of your Bike for better accuracy, Otherwise you might experience crappy monitoring..."),
                                                            actions: [
                                                              ElevatedButton(
                                                                onPressed: () =>
                                                                    Navigator.of(ctx)
                                                                        .pop(true),
                                                                child: const Text(
                                                                    "Okay"),
                                                              ),
                                                            ],
                                                          ),
                                                    );
                                                    await VehicleMonitorService()
                                                        .startMonitoring(
                                                      context: context,
                                                      userId:
                                                      auth.currentUser!.uid,
                                                      vehicleId: vehicle.id,
                                                      make: vehicle['make'],
                                                      model: vehicle['model'],
                                                      ref: ref,
                                                    );
                                                    monitoringVehicleId =
                                                        vehicle.id;
                                                  }
                                                  setState(() {});
                                                },
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: isMonitoring
                                                      ? Colors.orange
                                                      : Colors.green,
                                                ),
                                                child: Text(
                                                  isMonitoring
                                                      ? 'Stop'
                                                      : 'Start',
                                                  style: const TextStyle(
                                                      color: Colors.white),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    )
                                        : const SizedBox.shrink(),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        clipBehavior: Clip.none,
                      );
                    },
                    loading: () =>
                    const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Error: $e')),
                  );
                },
              ),
            ),
            SizedBox(height: 10.h),
            Container(
              height: 50.h,
              width: MediaQuery.of(context).size.width - 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 4,
                    spreadRadius: 3,
                  ),
                ],
              ),
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
                    Icon(Icons.add_circle,
                        size: 30.r, color: Color(0xffffffff)),
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
