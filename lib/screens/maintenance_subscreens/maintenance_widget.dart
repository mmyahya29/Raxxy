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
import 'chat_bot_screen.dart';

Widget maintenanceLogWidget(BuildContext context, VoidCallback rebuild) {
  final mileageController = TextEditingController();
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;

  return Container(
    height: 280.h,
    width: double.infinity,
    decoration: BoxDecoration(
      color: isDark ? const Color(0xFF1A1F3A) : Colors.white,
      borderRadius: BorderRadius.circular(30.r),
      border: Border.all(
        color: isDark ? const Color(0xFF8B7CFF).withOpacity(0.3) : Colors.blue.withOpacity(0.2),
        width: 1.5,
      ),
      boxShadow: [
        BoxShadow(
          color: isDark ? const Color(0xFF8B7CFF).withOpacity(0.05) : Colors.black.withOpacity(0.05),
          blurRadius: 20,
          spreadRadius: 2,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    padding: EdgeInsets.only(top: 20.h, bottom: 10.h),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          child: Row(
            children: [
              Icon(Icons.build_circle_outlined, color: const Color(0xFF00E5FF), size: 20.r),
              SizedBox(width: 8.w),
              Text(
                'SYSTEM DIAGNOSTICS',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF00E5FF),
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 15.h),
        Expanded(
          child: Consumer(
            builder: (context, ref, _) {
              final vehicles = ref.watch(vehiclesProvider);

              return vehicles.when(
                data: (list) {
                  if (list.isEmpty) {
                    return _buildEmptyState(theme, isDark, "No vehicles detected in network.");
                  }

                  final services = <Map<String, dynamic>>[];
                  for (int i = 0; i < list.length; i++) {
                    var v = list[i];
                    final serv = MaintenanceService.getMaintenanceStatusForVehicle(vehicle: v);
                    if (serv != null) services.addAll(serv);
                  }

                  if (services.isEmpty) {
                    return _buildEmptyState(theme, isDark, "All systems nominal. No pending maintenance.");
                  }

                  return ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    scrollDirection: Axis.horizontal,
                    itemCount: services.length,
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    separatorBuilder: (context, index) => SizedBox(width: 15.w),
                    itemBuilder: (context, index) {
                      final s = services[index];
                      final remaining = s["remaining"];

                      Color statusColor;
                      IconData statusIcon;

                      if (remaining <= 0) {
                        statusColor = const Color(0xFFFF5252);
                        statusIcon = Icons.warning_amber_rounded;
                      } else if (remaining <= 50) {
                        statusColor = const Color(0xFFFF9800);
                        statusIcon = Icons.priority_high_rounded;
                      } else {
                        statusColor = const Color(0xFF4CAF50);
                        statusIcon = Icons.check_circle_outline_rounded;
                      }

                      return _buildDiagnosticCard(
                        context,
                        s,
                        remaining,
                        statusColor,
                        statusIcon,
                        isDark,
                        mileageController,
                        ref,
                        rebuild,
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF))),
                error: (e, _) => Center(child: Text("Error: $e", style: const TextStyle(color: Colors.redAccent))),
              );
            },
          ),
        ),
      ],
    ),
  );
}

Widget _buildEmptyState(ThemeData theme, bool isDark, String message) {
  return Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.verified_user_outlined,
          size: 45.sp,
          color: isDark ? Colors.white24 : Colors.grey.withOpacity(0.5),
        ),
        SizedBox(height: 12.h),
        Text(
          message,
          style: TextStyle(
            color: isDark ? Colors.white54 : Colors.grey,
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
        ),
      ],
    ),
  );
}

Widget _buildDiagnosticCard(
    BuildContext context,
    Map<String, dynamic> service,
    double remaining,
    Color statusColor,
    IconData statusIcon,
    bool isDark,
    TextEditingController mileageController,
    WidgetRef ref,
    VoidCallback rebuild,
    ) {
  return InkWell(
    onTap: () => _showStyledUpdateDialog(context, service, mileageController, ref, rebuild, isDark),
    borderRadius: BorderRadius.circular(24.r),
    child: Container(
      width: 220.w,
      decoration: BoxDecoration(
        color: isDark ? statusColor.withOpacity(0.08) : statusColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: statusColor.withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.1),
            blurRadius: 15,
            spreadRadius: 1,
          ),
        ],
      ),
      padding: EdgeInsets.all(18.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Top Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(statusIcon, color: statusColor, size: 20.sp),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "${service["name"]}".toUpperCase(),
                      style: TextStyle(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white54 : Colors.black54,
                        letterSpacing: 1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      "${service["title"]}",
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : Colors.black87,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Bottom Data
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0A0E27).withOpacity(0.6) : Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: statusColor.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "REMAINING",
                      style: TextStyle(
                        fontSize: 9.sp,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white54 : Colors.grey,
                        letterSpacing: 1,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: remaining > 0 ? remaining : 0),
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        return Text(
                          "${value.toStringAsFixed(0)} km",
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w900,
                            color: statusColor,
                          ),
                        );
                      },
                    ),
                  ],
                ),
                Icon(Icons.arrow_forward_ios_rounded, color: statusColor.withOpacity(0.5), size: 14.sp),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

void _showStyledUpdateDialog(
    BuildContext context,
    Map<String, dynamic> s,
    TextEditingController controller,
    WidgetRef ref,
    VoidCallback rebuild,
    bool isDark,
    ) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1A1F3A) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24.r),
        side: BorderSide(color: const Color(0xFF00E5FF).withOpacity(0.5)),
      ),
      title: Text(
        "UPDATE MAINTENANCE",
        style: TextStyle(
          fontSize: 14.sp,
          fontWeight: FontWeight.w900,
          color: const Color(0xFF00E5FF),
          letterSpacing: 1.5,
        ),
      ),
      content: Text(
        "Select an input method to record this service event.",
        style: TextStyle(fontSize: 13.sp, color: isDark ? Colors.white70 : Colors.black87),
      ),
      actionsPadding: EdgeInsets.only(bottom: 15.h, right: 15.w, left: 15.w),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(ctx).pop();
            _showManualEntryDialog(context, s, controller, ref, rebuild, isDark);
          },
          child: Text("MANUAL ENTRY", style: TextStyle(color: isDark ? Colors.white54 : Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00E5FF).withOpacity(0.2),
            foregroundColor: const Color(0xFF00E5FF),
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
          ),
          onPressed: () {
            final distance = (s["distance"] as num).toDouble();
            MaintenanceService().updateMaintenaceState(s['vehicleId'], ref, distance, s["title"]);
            rebuild();
            Navigator.of(ctx).pop();
          },
          child: const Text("USE CURRENT"),
        ),
      ],
    ),
  );
}

void _showManualEntryDialog(
    BuildContext context,
    Map<String, dynamic> s,
    TextEditingController controller,
    WidgetRef ref,
    VoidCallback rebuild,
    bool isDark,
    ) {
  controller.clear();
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1A1F3A) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24.r),
        side: BorderSide(color: const Color(0xFF8B7CFF).withOpacity(0.5)),
      ),
      title: Text(
        "MANUAL MILEAGE",
        style: TextStyle(
          fontSize: 14.sp,
          fontWeight: FontWeight.w900,
          color: const Color(0xFF8B7CFF),
          letterSpacing: 1.5,
        ),
      ),
      content: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 16.sp, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          hintText: "Enter exact mileage",
          hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.black26),
          filled: true,
          fillColor: isDark ? const Color(0xFF0A0E27) : Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16.r),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16.r),
            borderSide: const BorderSide(color: Color(0xFF8B7CFF), width: 2),
          ),
          suffixText: "km",
          suffixStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text("CANCEL", style: TextStyle(color: isDark ? Colors.white54 : Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF8B7CFF),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
          ),
          onPressed: () {
            if (controller.text.trim().isNotEmpty) {
              MaintenanceService().updateMaintenaceState(
                  s["vehicleId"], ref, double.parse(controller.text.trim()), s["title"]
              );
              rebuild();
              Navigator.of(ctx).pop();
            }
          },
          child: const Text("SAVE DATA"),
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------
// Animated Chatbot Card Widget
// ---------------------------------------------------------

class AnimatedChatbotCardWidget extends StatefulWidget {
  const AnimatedChatbotCardWidget({Key? key}) : super(key: key);

  @override
  State<AnimatedChatbotCardWidget> createState() => _AnimatedChatbotCardWidgetState();
}

class _AnimatedChatbotCardWidgetState extends State<AnimatedChatbotCardWidget> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Container(
          height: 125.h,
          width: MediaQuery.of(context).size.width - 40.w,
          margin: EdgeInsets.symmetric(vertical: 10.h),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF6366F1).withOpacity(_pulseAnimation.value),
                const Color(0xFF8B5CF6),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(30.r),
            border: Border.all(
              color: Colors.white.withOpacity(0.2 * _pulseAnimation.value),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8B5CF6).withOpacity(0.3 * _pulseAnimation.value),
                blurRadius: 15,
                spreadRadius: 2,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ChatBotScreen()),
                );
              },
              borderRadius: BorderRadius.circular(30.r),
              highlightColor: Colors.white.withOpacity(0.1),
              splashColor: Colors.white.withOpacity(0.2),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
                child: Row(
                  children: [
                    // Icon Container
                    Container(
                      height: 65.h,
                      width: 65.w,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(22.r),
                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.1 * _pulseAnimation.value),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(Icons.smart_toy_outlined, color: Colors.white, size: 30.sp),
                          Positioned(
                            top: 15,
                            right: 15,
                            child: Container(
                              height: 8.r,
                              width: 8.r,
                              decoration: const BoxDecoration(
                                color: Color(0xFF00E5FF),
                                shape: BoxShape.circle,
                                boxShadow: [BoxShadow(color: Color(0xFF00E5FF), blurRadius: 4)],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 20.w),
                    // Text Column
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                "AI ASSISTANT",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 6.h),
                          Text(
                            "Ask me anything about your vehicle's health or telemetry",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w500,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    // Action Arrow
                    Container(
                      padding: EdgeInsets.all(8.r),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: Colors.white,
                        size: 16.sp,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}