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
  String? monitoringVehicleId;

  @override
  void initState() {
    super.initState();
    _initPermissionsAndStart();
  }

  Future<void> _initPermissionsAndStart() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.read(firebaseAuthProvider);
    final mileageController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0E27) : const Color(0xFFF4F5F9),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCustomAppBar(isDark),
            Expanded(
              child: Consumer(
                builder: (context, ref, _) {
                  final vehiclesAsync = ref.watch(vehiclesProvider);

                  return vehiclesAsync.when(
                    data: (vehicles) {
                      if (vehicles.isEmpty) {
                        return _buildEmptyState(isDark);
                      }

                      return ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                        itemCount: vehicles.length,
                        itemBuilder: (context, index) {
                          final vehicle = vehicles[index];
                          final isExpanded = expandedIndex == index;
                          final isMonitoring = monitoringVehicleId == vehicle.id;

                          return _buildVehicleCard(
                            context,
                            vehicle,
                            index,
                            isExpanded,
                            isMonitoring,
                            isDark,
                            auth,
                            mileageController,
                          );
                        },
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF8B7CFF))),
                    error: (e, _) => Center(child: Text('System Error: $e', style: const TextStyle(color: Colors.redAccent))),
                  );
                },
              ),
            ),
            _buildAddVehicleButton(context, isDark),
            SizedBox(height: 30.h)
          ],
        ),
      ),
    );
  }

  // ---- UI Components ----

  Widget _buildCustomAppBar(bool isDark) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1F3A) : Colors.white,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30.r)),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.5) : Colors.blue.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12.r),
            decoration: BoxDecoration(
              color: const Color(0xFF8B7CFF).withOpacity(0.15),
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Icon(Icons.garage_rounded, color: const Color(0xFF8B7CFF), size: 28.r),
          ),
          SizedBox(width: 15.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FLEET COMMAND',
                  style: TextStyle(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black87,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  'Select a vehicle to initialize telemetry',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white54 : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.commute_outlined, size: 60.r, color: isDark ? Colors.white24 : Colors.grey.withOpacity(0.5)),
          SizedBox(height: 15.h),
          Text(
            'NO VEHICLES DETECTED',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white54 : Colors.grey,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleCard(
      BuildContext context,
      dynamic vehicle,
      int index,
      bool isExpanded,
      bool isMonitoring,
      bool isDark,
      dynamic auth,
      TextEditingController mileageController,
      ) {
    Color accentColor = isMonitoring ? const Color(0xFF00E5FF) : const Color(0xFF8B7CFF);

    return GestureDetector(
      onTap: () => setState(() => expandedIndex = isExpanded ? null : index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        margin: EdgeInsets.only(bottom: 15.h),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1F3A) : Colors.white,
          borderRadius: BorderRadius.circular(24.r),
          border: Border.all(
            color: isMonitoring ? accentColor.withOpacity(0.6) : (isDark ? Colors.white10 : Colors.grey.shade200),
            width: isMonitoring ? 2 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isMonitoring ? accentColor.withOpacity(0.2) : Colors.black.withOpacity(0.05),
              blurRadius: isMonitoring ? 20 : 10,
              spreadRadius: isMonitoring ? 2 : 0,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24.r),
          child: Column(
            children: [
              // Card Header
              Container(
                padding: EdgeInsets.all(16.r),
                decoration: BoxDecoration(
                  gradient: isMonitoring
                      ? LinearGradient(
                    colors: [accentColor.withOpacity(0.15), Colors.transparent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                      : null,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(12.r),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black26 : Colors.grey.shade100,
                        shape: BoxShape.circle,
                        border: Border.all(color: isMonitoring ? accentColor.withOpacity(0.5) : Colors.transparent),
                      ),
                      child: Icon(
                        (vehicle['type'].toString().toLowerCase() == 'car')
                            ? Icons.directions_car_filled_rounded
                            : Icons.two_wheeler_rounded,
                        color: isMonitoring ? accentColor : (isDark ? Colors.white70 : Colors.black54),
                        size: 24.r,
                      ),
                    ),
                    SizedBox(width: 15.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${vehicle['make']} ${vehicle['model']}'.toUpperCase(),
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : Colors.black87,
                              letterSpacing: 1,
                            ),
                          ),
                          if (isMonitoring)
                            Row(
                              children: [
                                Container(
                                  width: 6.r,
                                  height: 6.r,
                                  decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle),
                                ),
                                SizedBox(width: 6.w),
                                Text(
                                  'ACTIVE TELEMETRY',
                                  style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.bold, color: accentColor),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    Icon(
                      isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      color: isDark ? Colors.white30 : Colors.grey,
                    ),
                  ],
                ),
              ),

              // Expanded Content
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                alignment: Alignment.topCenter,
                child: isExpanded
                    ? Container(
                  padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
                  child: Column(
                    children: [
                      Divider(color: isDark ? Colors.white10 : Colors.grey.shade200),
                      SizedBox(height: 10.h),
                      // Data Pills
                      Row(
                        children: [
                          Expanded(child: _buildDataPill('TYPE', vehicle['type'].toString().toUpperCase(), isDark)),
                          SizedBox(width: 8.w),
                          Expanded(child: _buildDataPill('YEAR', vehicle['year'].toString(), isDark)),
                          SizedBox(width: 8.w),
                          Expanded(
                            flex: 2,
                            child: _buildDataPill(
                              'MILEAGE',
                              '${(vehicle['mileage'] as num).toDouble().toStringAsFixed(1)} km',
                              isDark,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20.h),
                      // Action Buttons
                      Row(
                        children: [
                          // Delete Button
                          Expanded(
                            flex: 1,
                            child: GestureDetector(
                              onTap: () => _handleDelete(context, vehicle, isMonitoring, auth, isDark),
                              child: Container(
                                padding: EdgeInsets.symmetric(vertical: 12.h),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF5252).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16.r),
                                  border: Border.all(color: const Color(0xFFFF5252).withOpacity(0.3)),
                                ),
                                child: Icon(Icons.delete_outline_rounded, color: const Color(0xFFFF5252), size: 20.r),
                              ),
                            ),
                          ),
                          SizedBox(width: 10.w),
                          // Start/Stop Button
                          Expanded(
                            flex: 4,
                            child: GestureDetector(
                              onTap: () => _handleMonitoringToggle(
                                context,
                                vehicle,
                                isMonitoring,
                                auth,
                                mileageController,
                                isDark,
                              ),
                              child: Container(
                                padding: EdgeInsets.symmetric(vertical: 12.h),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: isMonitoring
                                        ? [const Color(0xFFFF9800), const Color(0xFFFF5252)] // Stop (Orange/Red)
                                        : [const Color(0xFF00E5FF), const Color(0xFF2196F3)], // Start (Cyan/Blue)
                                  ),
                                  borderRadius: BorderRadius.circular(16.r),
                                  boxShadow: [
                                    BoxShadow(
                                      color: isMonitoring
                                          ? const Color(0xFFFF9800).withOpacity(0.3)
                                          : const Color(0xFF00E5FF).withOpacity(0.3),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      isMonitoring ? Icons.stop_circle_rounded : Icons.play_circle_fill_rounded,
                                      color: Colors.white,
                                      size: 20.r,
                                    ),
                                    SizedBox(width: 8.w),
                                    Text(
                                      isMonitoring ? 'TERMINATE SESSION' : 'INITIALIZE SESSION',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ],
                                ),
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
      ),
    );
  }

  Widget _buildDataPill(String label, String value, bool isDark) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 8.w),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0A0E27) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: isDark ? Colors.white10 : Colors.transparent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 8.sp, fontWeight: FontWeight.bold, color: isDark ? Colors.white54 : Colors.grey)),
          SizedBox(height: 2.h),
          Text(
            value,
            style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildAddVehicleButton(BuildContext context, bool isDark) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 10.h, 20.w, 20.h),
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddVehicleScreen())),
        borderRadius: BorderRadius.circular(20.r),
        child: Container(
          height: 55.h,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20.r),
            gradient: const LinearGradient(
              colors: [Color(0xFF8B7CFF), Color(0xFF00E5FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(color: const Color(0xFF00E5FF).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5)),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_circle_outline_rounded, size: 24.r, color: Colors.white),
              SizedBox(width: 8.w),
              Text(
                'REGISTER NEW VEHICLE',
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- Logic & Custom Dialogs ----

  Future<void> _handleDelete(BuildContext context, dynamic vehicle, bool isMonitoring, dynamic auth, bool isDark) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _buildCustomDialog(
        context: ctx,
        isDark: isDark,
        title: "CONFIRM DELETION",
        titleColor: const Color(0xFFFF5252),
        content: "Are you sure you want to purge ${vehicle['make']} ${vehicle['model']} from the fleet network?\n\nThis action is irreversible.",
        confirmText: "PURGE VEHICLE",
        confirmColor: const Color(0xFFFF5252),
      ),
    );

    if (confirmed == true) {
      if (isMonitoring) {
        final stopConfirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => _buildCustomDialog(
            context: ctx,
            isDark: isDark,
            title: "ACTIVE TELEMETRY",
            titleColor: const Color(0xFFFF9800),
            content: "This vehicle is currently active. Do you want to force terminate the session and delete?",
            confirmText: "TERMINATE & PURGE",
            confirmColor: const Color(0xFFFF5252),
          ),
        );

        if (stopConfirmed == true) {
          VehicleMonitorService().stopMonitoring(ref);
          monitoringVehicleId = null;
        } else {
          return;
        }
      }

      try {
        await ref.read(firestoreProvider)
            .collection('users')
            .doc(auth.currentUser?.uid)
            .collection('vehicles')
            .doc(vehicle.id)
            .delete();

        if (mounted) {
          showAppSnackBar(
            context,
            '✅ ${vehicle['make']} deleted successfully',
            backgroundColor: Colors.green,
          );
          setState(() {});
        }
      } catch (e) {
        if (mounted) {
          showAppSnackBar(
            context,
            '❌ Error: $e',
            backgroundColor: Colors.red,
          );
        }
      }
    }
  }

  Future<void> _handleMonitoringToggle(
      BuildContext context,
      dynamic vehicle,
      bool isMonitoring,
      dynamic auth,
      TextEditingController mileageController,
      bool isDark,
      ) async {
    if (isMonitoring) {
      // STOP
      mileageController.clear();
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1A1F3A) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24.r),
            side: BorderSide(color: const Color(0xFFFF9800).withOpacity(0.5)),
          ),
          title: Text(
            "TERMINATE SESSION",
            style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w900, color: const Color(0xFFFF9800), letterSpacing: 1.5),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Enter new odometer reading to recalibrate hardware inaccuracies, or leave empty to use GPS distance.",
                style: TextStyle(fontSize: 12.sp, color: isDark ? Colors.white70 : Colors.black87),
              ),
              SizedBox(height: 15.h),
              TextField(
                controller: mileageController,
                keyboardType: TextInputType.number,
                style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: "GPS Distance (Default)",
                  hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.black26),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0A0E27) : Colors.grey.shade100,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16.r), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16.r), borderSide: const BorderSide(color: Color(0xFFFF9800), width: 2)),
                  suffixText: "km",
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text("CANCEL", style: TextStyle(color: isDark ? Colors.white54 : Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF9800), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r))),
              onPressed: () {
                final inputText = mileageController.text.trim();
                if (inputText.isEmpty) {
                  VehicleMonitorService().stopMonitoring(ref);
                  monitoringVehicleId = null;
                  setState(() {});
                  Navigator.of(ctx).pop();
                } else {
                  final newMileage = double.tryParse(inputText);
                  if (newMileage != null && newMileage >= 0) {
                    final currentMileage = (vehicle['mileage'] as num).toDouble();
                    final difference = newMileage - currentMileage;

                    if (difference < 0) {
                      showAppSnackBar(
                        context,
                        '⚠️ New mileage cannot be lower than current ($currentMileage km)',
                        backgroundColor: Colors.orange,
                      );
                      return;
                    }
                    VehicleMonitorService().stopMonitoring(ref, manualMileage: difference);
                    monitoringVehicleId = null;
                    setState(() {});
                    Navigator.of(ctx).pop();
                  }
                }
              },
              child: const Text("END DRIVE"),
            ),
          ],
        ),
      );
    } else {
      // START
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => _buildCustomDialog(
          context: ctx,
          isDark: isDark,
          title: "SYSTEM CALIBRATION",
          titleColor: const Color(0xFF00E5FF),
          content: "Ensure your device is securely mounted on the dashboard or a phone stand. Unstable placement will result in inaccurate G-Force and telemetry readings.",
          confirmText: "ACKNOWLEDGE",
          confirmColor: const Color(0xFF00E5FF),
        ),
      );

      if (proceed == true) {
        await VehicleMonitorService().startMonitoring(
          context: context,
          userId: auth.currentUser!.uid,
          vehicleId: vehicle.id,
          make: vehicle['make'],
          model: vehicle['model'],
          ref: ref,
        );
        setState(() => monitoringVehicleId = vehicle.id);
      }
    }
  }

  Widget _buildCustomDialog({
    required BuildContext context,
    required bool isDark,
    required String title,
    required Color titleColor,
    required String content,
    required String confirmText,
    required Color confirmColor,
  }) {
    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1A1F3A) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24.r),
        side: BorderSide(color: titleColor.withOpacity(0.5)),
      ),
      title: Text(
        title,
        style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w900, color: titleColor, letterSpacing: 1.5),
      ),
      content: Text(
        content,
        style: TextStyle(fontSize: 13.sp, color: isDark ? Colors.white70 : Colors.black87, height: 1.4),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text("CANCEL", style: TextStyle(color: isDark ? Colors.white54 : Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: confirmColor.withOpacity(0.2),
            foregroundColor: confirmColor,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmText, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}