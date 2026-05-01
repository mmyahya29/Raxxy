import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_sms/flutter_sms.dart';

class GuardianAlertScreen extends StatefulWidget {
  final String driverName;
  final String distance;
  final String maxSpeed;
  final int harshBrakes;
  final int harshAccelerations;
  final String guardianContact;

  const GuardianAlertScreen({
    super.key,
    required this.driverName,
    required this.distance,
    required this.maxSpeed,
    required this.harshBrakes,
    required this.harshAccelerations,
    required this.guardianContact,
  });

  @override
  State<GuardianAlertScreen> createState() => _GuardianAlertScreenState();
}

class _GuardianAlertScreenState extends State<GuardianAlertScreen> {
  bool _smsSent = false;
  bool _isSending = false;
  String? _smsError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sendGuardianSms();
    });
  }

  Future<void> _sendGuardianSms() async {
    setState(() {
      _isSending = true;
      _smsError = null;
    });

    final smsMessage = "🛡️ RAXXY Guardian Alert:\n"
        "${widget.driverName} has finished driving.\n"
        "• Distance: ${widget.distance} km\n"
        "• Max Speed: ${widget.maxSpeed} km/h\n"
        "• Harsh Brakes: ${widget.harshBrakes}\n"
        "• Harsh Accels: ${widget.harshAccelerations}";

    try {
      await sendSMS(
        message: smsMessage,
        recipients: [widget.guardianContact],
        sendDirect: true,
      );
      if (mounted) {
        setState(() {
          _smsSent = true;
          _isSending = false;
        });
      }
      debugPrint("✅ Guardian Summary SMS sent successfully!");
    } catch (e) {
      if (mounted) {
        setState(() {
          _smsError = e.toString();
          _isSending = false;
        });
      }
      debugPrint("❌ Failed to send Guardian SMS: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: !_isSending,
      child: Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0E27) : const Color(0xFFF4F5F9),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1F3A) : Colors.white,
        elevation: 0,
        title: Text(
          "GUARDIAN ALERT",
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w900,
            color: const Color(0xFFFF9800),
            letterSpacing: 2,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded,
              color: _isSending
                  ? (isDark ? Colors.white24 : Colors.black26)
                  : (isDark ? Colors.white70 : Colors.black54)),
          onPressed: _isSending ? null : () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Shield icon header
              Center(
                child: Container(
                  width: 80.r,
                  height: 80.r,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFFF9800).withOpacity(0.15),
                    border: Border.all(
                        color: const Color(0xFFFF9800).withOpacity(0.5), width: 2),
                  ),
                  child: Icon(
                    Icons.shield_rounded,
                    color: const Color(0xFFFF9800),
                    size: 40.r,
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              Center(
                child: Text(
                  "Trip Summary",
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black87,
                    letterSpacing: 1,
                  ),
                ),
              ),
              Center(
                child: Text(
                  "Your guardian will be notified of this drive.",
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(height: 24.h),

              // Trip summary card
              Container(
                padding: EdgeInsets.all(20.w),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A1F3A) : Colors.white,
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(
                      color: const Color(0xFFFF9800).withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatRow(
                      icon: Icons.person_rounded,
                      label: "DRIVER",
                      value: widget.driverName,
                      isDark: isDark,
                    ),
                    Divider(
                        color: isDark ? Colors.white12 : Colors.black12,
                        height: 20.h),
                    _buildStatRow(
                      icon: Icons.route_rounded,
                      label: "DISTANCE",
                      value: "${widget.distance} km",
                      isDark: isDark,
                    ),
                    Divider(
                        color: isDark ? Colors.white12 : Colors.black12,
                        height: 20.h),
                    _buildStatRow(
                      icon: Icons.speed_rounded,
                      label: "MAX SPEED",
                      value: "${widget.maxSpeed} km/h",
                      isDark: isDark,
                    ),
                    Divider(
                        color: isDark ? Colors.white12 : Colors.black12,
                        height: 20.h),
                    _buildStatRow(
                      icon: Icons.warning_amber_rounded,
                      label: "HARSH BRAKES",
                      value: "${widget.harshBrakes}",
                      isDark: isDark,
                      valueColor: widget.harshBrakes > 0
                          ? const Color(0xFFFF5252)
                          : null,
                    ),
                    Divider(
                        color: isDark ? Colors.white12 : Colors.black12,
                        height: 20.h),
                    _buildStatRow(
                      icon: Icons.bolt_rounded,
                      label: "HARSH ACCELS",
                      value: "${widget.harshAccelerations}",
                      isDark: isDark,
                      valueColor: widget.harshAccelerations > 0
                          ? const Color(0xFFFF9800)
                          : null,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20.h),

              // SMS status card
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A1F3A) : Colors.white,
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(
                    color: _smsSent
                        ? Colors.green.withOpacity(0.4)
                        : _smsError != null
                            ? const Color(0xFFFF5252).withOpacity(0.4)
                            : const Color(0xFFFF9800).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    if (_isSending)
                      SizedBox(
                        width: 20.r,
                        height: 20.r,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: const Color(0xFFFF9800),
                        ),
                      )
                    else
                      Icon(
                        _smsSent
                            ? Icons.check_circle_rounded
                            : _smsError != null
                                ? Icons.error_rounded
                                : Icons.sms_rounded,
                        color: _smsSent
                            ? Colors.green
                            : _smsError != null
                                ? const Color(0xFFFF5252)
                                : const Color(0xFFFF9800),
                        size: 20.r,
                      ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Text(
                        _isSending
                            ? "Sending alert to guardian..."
                            : _smsSent
                                ? "Guardian notified successfully!"
                                : _smsError != null
                                    ? "Failed to send SMS. Please contact your guardian directly: ${widget.guardianContact}"
                                    : "Guardian alert pending.",
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: _smsSent
                              ? Colors.green
                              : _smsError != null
                                  ? const Color(0xFFFF5252)
                                  : isDark
                                      ? Colors.white70
                                      : Colors.black54,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24.h),

              // Done button
              SizedBox(
                width: double.infinity,
                height: 52.h,
                child: ElevatedButton(
                  onPressed: _isSending ? null : () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF9800),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                  ),
                  child: Text(
                    "DONE",
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),   // Scaffold
    );   // PopScope
  }

  Widget _buildStatRow({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon,
            color: const Color(0xFFFF9800).withOpacity(0.8), size: 18.r),
        SizedBox(width: 10.w),
        Text(
          label,
          style: TextStyle(
            fontSize: 11.sp,
            color: isDark ? Colors.white38 : Colors.black38,
            letterSpacing: 1,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w700,
            color: valueColor ?? (isDark ? Colors.white : Colors.black87),
          ),
        ),
      ],
    );
  }
}
