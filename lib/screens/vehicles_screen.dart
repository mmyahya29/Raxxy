import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:persistent_bottom_nav_bar/persistent_bottom_nav_bar.dart';
import 'package:raxxy/widgets/reusable_widgets.dart';
import '../providers/provider.dart';
import '../providers/vehicle_provider.dart';
import '../services/monitoring_service/vehicle_monitor_service.dart';
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
      appBar: AppBar(title: const Text('What are we Driving today?')),
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
                          final isMonitoring =
                              monitoringVehicleId == vehicle.id;

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
                                        (vehicle['type'] == 'car' ||
                                                vehicle['type'] == 'Car')
                                            ? Icons
                                                .directions_car_filled_rounded
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
                                    child:
                                        isExpanded
                                            ? Padding(
                                              padding: EdgeInsets.only(
                                                top: 10.h,
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  SizedBox(height: 10.h),
                                                  Text(
                                                    'Type: ${vehicle['type']}',
                                                  ),
                                                  Text(
                                                    'Year: ${vehicle['year']}',
                                                  ),
                                                  Text(
                                                    'Mileage: ${(vehicle['mileage'] as num).toDouble().toStringAsFixed(2)} km',
                                                  ),
                                                  SizedBox(height: 10.h),
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceEvenly,
                                                    children: [
                                                      // DELETE BUTTON WITH CONFIRMATION
                                                      ElevatedButton(
                                                        onPressed: () async {
                                                          // Show confirmation dialog
                                                          final confirmed = await showDialog<
                                                            bool
                                                          >(
                                                            context: context,
                                                            builder:
                                                                (
                                                                  ctx,
                                                                ) => AlertDialog(
                                                                  title: const Text(
                                                                    "Delete Vehicle?",
                                                                  ),
                                                                  content: Text(
                                                                    "Are you sure you want to delete ${vehicle['make']} ${vehicle['model']}?\n\nThis will permanently remove the vehicle and all its trip history.",
                                                                  ),
                                                                  actions: [
                                                                    TextButton(
                                                                      onPressed:
                                                                          () => Navigator.of(
                                                                            ctx,
                                                                          ).pop(
                                                                            false,
                                                                          ),
                                                                      child: const Text(
                                                                        "Cancel",
                                                                      ),
                                                                    ),
                                                                    ElevatedButton(
                                                                      onPressed:
                                                                          () => Navigator.of(
                                                                            ctx,
                                                                          ).pop(
                                                                            true,
                                                                          ),
                                                                      style: ElevatedButton.styleFrom(
                                                                        backgroundColor:
                                                                            Colors.red,
                                                                      ),
                                                                      child: const Text(
                                                                        "Delete",
                                                                        style: TextStyle(
                                                                          color:
                                                                              Colors.white,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                          );

                                                          // If user confirmed deletion
                                                          if (confirmed ==
                                                              true) {
                                                            // If vehicle is being monitored, stop monitoring first
                                                            if (monitoringVehicleId ==
                                                                vehicle.id) {
                                                              final stopConfirmed = await showDialog<
                                                                bool
                                                              >(
                                                                context:
                                                                    context,
                                                                builder:
                                                                    (
                                                                      ctx,
                                                                    ) => AlertDialog(
                                                                      title: const Text(
                                                                        "Stop Monitoring First",
                                                                      ),
                                                                      content:
                                                                          const Text(
                                                                            "This vehicle is currently being monitored. Do you want to stop monitoring and delete it?",
                                                                          ),
                                                                      actions: [
                                                                        TextButton(
                                                                          onPressed:
                                                                              () => Navigator.of(
                                                                                ctx,
                                                                              ).pop(
                                                                                false,
                                                                              ),
                                                                          child: const Text(
                                                                            "Cancel",
                                                                          ),
                                                                        ),
                                                                        ElevatedButton(
                                                                          onPressed:
                                                                              () => Navigator.of(
                                                                                ctx,
                                                                              ).pop(
                                                                                true,
                                                                              ),
                                                                          style: ElevatedButton.styleFrom(
                                                                            backgroundColor:
                                                                                Colors.red,
                                                                          ),
                                                                          child: const Text(
                                                                            "Stop & Delete",
                                                                            style: TextStyle(
                                                                              color:
                                                                                  Colors.white,
                                                                            ),
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    ),
                                                              );

                                                              if (stopConfirmed ==
                                                                  true) {
                                                                // Stop monitoring without mileage dialog
                                                                VehicleMonitorService()
                                                                    .stopMonitoring(
                                                                      ref,
                                                                    );
                                                                monitoringVehicleId =
                                                                    null;
                                                              } else {
                                                                return; // User cancelled
                                                              }
                                                            }

                                                            // Delete the vehicle
                                                            try {
                                                              await ref
                                                                  .read(
                                                                    firestoreProvider,
                                                                  )
                                                                  .collection(
                                                                    'users',
                                                                  )
                                                                  .doc(
                                                                    auth
                                                                        .currentUser
                                                                        ?.uid,
                                                                  )
                                                                  .collection(
                                                                    'vehicles',
                                                                  )
                                                                  .doc(
                                                                    vehicle.id,
                                                                  )
                                                                  .delete();

                                                              if (context
                                                                  .mounted) {
                                                                ScaffoldMessenger.of(
                                                                  context,
                                                                ).showSnackBar(
                                                                  SnackBar(
                                                                    content: Text(
                                                                      '✅ ${vehicle['make']} ${vehicle['model']} deleted successfully',
                                                                    ),
                                                                    backgroundColor:
                                                                        Colors
                                                                            .green,
                                                                  ),
                                                                );
                                                              }
                                                              setState(() {});
                                                            } catch (e) {
                                                              if (context
                                                                  .mounted) {
                                                                ScaffoldMessenger.of(
                                                                  context,
                                                                ).showSnackBar(
                                                                  SnackBar(
                                                                    content: Text(
                                                                      '❌ Error deleting vehicle: $e',
                                                                    ),
                                                                    backgroundColor:
                                                                        Colors
                                                                            .red,
                                                                  ),
                                                                );
                                                              }
                                                            }
                                                          }
                                                        },
                                                        style:
                                                            ElevatedButton.styleFrom(
                                                              backgroundColor:
                                                                  Colors.red,
                                                            ),
                                                        child: const Text(
                                                          'Delete',
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                          ),
                                                        ),
                                                      ),

                                                      // START/STOP MONITORING BUTTON
                                                      ElevatedButton(
                                                        onPressed: () async {
                                                          if (isMonitoring) {
                                                            // STOP MONITORING - Show mileage dialog
                                                            showDialog(
                                                              context: context,
                                                              builder:
                                                                  (
                                                                    ctx,
                                                                  ) => AlertDialog(
                                                                    title: const Text(
                                                                      "Stop Monitoring",
                                                                    ),
                                                                    content: Column(
                                                                      mainAxisSize:
                                                                          MainAxisSize
                                                                              .min,
                                                                      crossAxisAlignment:
                                                                          CrossAxisAlignment
                                                                              .start,
                                                                      children: [
                                                                        const Text(
                                                                          "Enter new mileage to correct hardware inaccuracies, or leave empty to use GPS-calculated distance.",
                                                                          style: TextStyle(
                                                                            fontSize:
                                                                                14,
                                                                          ),
                                                                        ),
                                                                        SizedBox(
                                                                          height:
                                                                              10.h,
                                                                        ),
                                                                        TextField(
                                                                          controller:
                                                                              mileageController,
                                                                          keyboardType:
                                                                              TextInputType.number,
                                                                          decoration: const InputDecoration(
                                                                            hintText:
                                                                                "Leave empty for GPS distance",
                                                                            labelText:
                                                                                "New Mileage (km) - Optional",
                                                                            border:
                                                                                OutlineInputBorder(),
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                    actions: [
                                                                      TextButton(
                                                                        onPressed: () {
                                                                          Navigator.of(
                                                                            ctx,
                                                                          ).pop();
                                                                        },
                                                                        child: const Text(
                                                                          "Cancel",
                                                                        ),
                                                                      ),
                                                                      ElevatedButton(
                                                                        onPressed: () async {
                                                                          final inputText =
                                                                              mileageController.text.trim();

                                                                          if (inputText
                                                                              .isEmpty) {
                                                                            // Empty string - Use GPS distance (add to current mileage)
                                                                            VehicleMonitorService().stopMonitoring(
                                                                              ref,
                                                                            );
                                                                            monitoringVehicleId =
                                                                                null;
                                                                            setState(
                                                                              () {},
                                                                            );
                                                                            Navigator.of(
                                                                              ctx,
                                                                            ).pop();
                                                                            mileageController.clear();
                                                                          } else {
                                                                            // User entered a number - Set mileage TO this value
                                                                            final newMileage = double.tryParse(
                                                                              inputText,
                                                                            );

                                                                            if (newMileage !=
                                                                                    null &&
                                                                                newMileage >=
                                                                                    0) {
                                                                              // Calculate the difference from current mileage
                                                                              final currentMileage =
                                                                                  (vehicle['mileage']
                                                                                          as num)
                                                                                      .toDouble();
                                                                              final mileageDifference =
                                                                                  newMileage -
                                                                                  currentMileage;

                                                                              if (mileageDifference <
                                                                                  0) {
                                                                                // New mileage is less than current - show error
                                                                                ScaffoldMessenger.of(
                                                                                  context,
                                                                                ).showSnackBar(
                                                                                  SnackBar(
                                                                                    content: Text(
                                                                                      '⚠️ New mileage ($newMileage km) cannot be less than current mileage ($currentMileage km)',
                                                                                    ),
                                                                                    backgroundColor:
                                                                                        Colors.orange,
                                                                                    duration: const Duration(
                                                                                      seconds:
                                                                                          3,
                                                                                    ),
                                                                                  ),
                                                                                );
                                                                                return;
                                                                              }

                                                                              // Use the difference as manual mileage to add
                                                                              VehicleMonitorService().stopMonitoring(
                                                                                ref,
                                                                                manualMileage:
                                                                                    mileageDifference,
                                                                              );
                                                                              monitoringVehicleId =
                                                                                  null;
                                                                              setState(
                                                                                () {},
                                                                              );
                                                                              Navigator.of(
                                                                                ctx,
                                                                              ).pop();
                                                                              mileageController.clear();
                                                                            } else {
                                                                              // Invalid number
                                                                              ScaffoldMessenger.of(
                                                                                context,
                                                                              ).showSnackBar(
                                                                                const SnackBar(
                                                                                  content: Text(
                                                                                    '⚠️ Please enter a valid mileage value',
                                                                                  ),
                                                                                  backgroundColor:
                                                                                      Colors.orange,
                                                                                ),
                                                                              );
                                                                            }
                                                                          }
                                                                        },
                                                                        child: const Text(
                                                                          "Stop Monitoring",
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                            );
                                                          } else {
                                                            // START MONITORING - Show info dialog
                                                            showDialog(
                                                              context: context,
                                                              builder:
                                                                  (
                                                                    ctx,
                                                                  ) => AlertDialog(
                                                                    title: const Text(
                                                                      "Starting to drive?",
                                                                    ),
                                                                    content:
                                                                        const Text(
                                                                          "Make sure to set your device on the dashboard of your car or on a phone stand of your Bike for better accuracy, Otherwise you might experience crappy monitoring...",
                                                                        ),
                                                                    actions: [
                                                                      ElevatedButton(
                                                                        onPressed:
                                                                            () =>
                                                                                Navigator.of(ctx).pop(),
                                                                        child: const Text(
                                                                          "Okay",
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                            );
                                                            await VehicleMonitorService()
                                                                .startMonitoring(
                                                                  context:
                                                                      context,
                                                                  userId:
                                                                      auth
                                                                          .currentUser!
                                                                          .uid,
                                                                  vehicleId:
                                                                      vehicle
                                                                          .id,
                                                                  make:
                                                                      vehicle['make'],
                                                                  model:
                                                                      vehicle['model'],
                                                                  ref: ref,
                                                                );
                                                            monitoringVehicleId =
                                                                vehicle.id;
                                                          }
                                                          setState(() {});
                                                        },
                                                        style:
                                                            ElevatedButton.styleFrom(
                                                              backgroundColor:
                                                                  isMonitoring
                                                                      ? Colors
                                                                          .orange
                                                                      : Colors
                                                                          .green,
                                                            ),
                                                        child: Text(
                                                          isMonitoring
                                                              ? 'Stop'
                                                              : 'Start',
                                                          style:
                                                              const TextStyle(
                                                                color:
                                                                    Colors
                                                                        .white,
                                                              ),
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
                    loading:
                        () => const Center(child: CircularProgressIndicator()),
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
                  backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
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
                    Icon(
                      Icons.add_circle,
                      size: 30.r,
                      color: Color(0xffffffff),
                    ),
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
