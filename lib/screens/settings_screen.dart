import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:persistent_bottom_nav_bar/persistent_bottom_nav_bar.dart';
import 'package:raxxy/screens/settings_subscreens/user_management.dart';
import '../providers/provider.dart';
import '../providers/safety_feature_provider.dart';
import '../providers/sensor_thresholds_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/reusable_widgets.dart';
import '../services/notifications_services.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  final PersistentTabController controller;
  const SettingsScreen({super.key, required this.controller});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final emNumController = TextEditingController();
  final CoachingService _coachingService = CoachingService();

  @override
  void initState() {
    super.initState();
    _syncEmergencyContact();
  }

  Future<void> _syncEmergencyContact() async {
    final prefs = ref.read(sharedPreferencesProvider);
    final emergencyContact = prefs.getString('emergency_contact');
    if (emergencyContact != null) {
      emNumController.text = emergencyContact;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.read(firebaseAuthProvider);
    final username = auth.currentUser?.displayName ?? 'Pilot';
    final themeMode = ref.watch(themeNotifierProvider);
    final crash = ref.watch(featureNotifierProvider);
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);
    final thresholds = ref.watch(sensorThresholdsProvider);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0E27) : const Color(0xFFF4F5F9),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── CUSTOM HEADER ──────────────────────────────
              _buildCustomAppBar(isDark),

              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 10.h),

                    // ── PROFILE HEADER ──────────────────────────────
                    _buildProfileHeader(context, username, isDark),
                    SizedBox(height: 35.h),

                    // ── SYSTEM PREFERENCES ─────────────────────────────
                    _buildHudSectionHeader('SYSTEM PREFERENCES', Icons.display_settings_rounded, const Color(0xFF8B7CFF), isDark),
                    SizedBox(height: 15.h),
                    Container(
                      decoration: _cardDecoration(context, isDark),
                      child: Column(
                        children: [
                          _buildSettingTile(
                            icon: isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                            iconColor: const Color(0xFFFF9800),
                            title: 'Dark Mode Interface',
                            subtitle: 'Toggle high-contrast HUD',
                            isDark: isDark,
                            trailing: Switch.adaptive(
                              value: isDark,
                              activeColor: const Color(0xFF00E5FF),
                              onChanged: (_) => ref.read(themeNotifierProvider.notifier).toggleTheme(),
                            ),
                          ),
                          Divider(height: 1, indent: 60.w, endIndent: 20.w, color: isDark ? Colors.white10 : Colors.black12),
                          _buildSettingTile(
                            icon: Icons.security_rounded,
                            iconColor: const Color(0xFF00E5FF),
                            title: 'Crash Detection',
                            subtitle: crash ? 'System Active' : 'System Offline',
                            isDark: isDark,
                            trailing: Switch.adaptive(
                              value: crash,
                              activeColor: const Color(0xFF4CAF50),
                              onChanged: (val) {
                                ref.read(featureNotifierProvider.notifier).toggleFeature();
                                _showStatusSnack(context, val);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── EMERGENCY CONTACT (animated) ─────────────────
                    AnimatedSize(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutCubic,
                      child: crash
                          ? Padding(
                        padding: EdgeInsets.only(top: 15.h),
                        child: _buildEmergencyInputCard(isDark),
                      )
                          : const SizedBox.shrink(),
                    ),

                    // ── SENSOR CALIBRATION ────────────────────────────
                    SizedBox(height: 35.h),
                    _buildHudSectionHeader('TELEMETRY CALIBRATION', Icons.tune_rounded, const Color(0xFF00E5FF), isDark),
                    SizedBox(height: 15.h),

                    // Module: Acceleration & Braking
                    _buildCalibrationModule(
                      context,
                      'ACCELERATION & BRAKING',
                      Icons.speed_rounded,
                      const Color(0xFFFF9800),
                      isDark,
                      [
                        _buildSliderTile(
                          context: context, title: 'Min Speed Threshold', subtitle: 'Events ignored below this speed',
                          value: thresholds.minSpeedThresholdKmh, defaultValue: SensorThresholdDefaults.minSpeedThresholdKmh,
                          min: 0.0, max: 30.0, divisions: 30, unit: 'km/h', isDark: isDark,
                          onChanged: (v) => _updateThresholds(thresholds.copyWith(minSpeedThresholdKmh: v)),
                        ),
                        _buildSliderTile(
                          context: context, title: 'Harsh Event Threshold', subtitle: 'G-force needed to trigger',
                          value: thresholds.accelerationThreshold, defaultValue: SensorThresholdDefaults.accelerationThreshold,
                          min: 0.5, max: 6.0, divisions: 55, unit: 'm/s²', isDark: isDark,
                          onChanged: (v) => _updateThresholds(thresholds.copyWith(accelerationThreshold: v)),
                        ),
                        _buildSliderTile(
                          context: context, title: 'Noise Filter', subtitle: 'Max std deviation before discarding',
                          value: thresholds.jitterThreshold, defaultValue: SensorThresholdDefaults.jitterThreshold,
                          min: 0.5, max: 6.0, divisions: 55, unit: 'm/s²', isDark: isDark,
                          onChanged: (v) => _updateThresholds(thresholds.copyWith(jitterThreshold: v)),
                        ),
                      ],
                    ),
                    SizedBox(height: 15.h),

                    // Module: Turn Detection
                    _buildCalibrationModule(
                      context,
                      'LATERAL DETECTION',
                      Icons.turn_right_rounded,
                      const Color(0xFF00E5FF),
                      isDark,
                      [
                        _buildSliderTile(
                          context: context, title: 'Lateral Force Limit', subtitle: 'Force to begin turn detection',
                          value: thresholds.turnForceThreshold, defaultValue: SensorThresholdDefaults.turnForceThreshold,
                          min: 0.5, max: 5.0, divisions: 45, unit: 'm/s²', isDark: isDark,
                          onChanged: (v) => _updateThresholds(thresholds.copyWith(turnForceThreshold: v)),
                        ),
                        _buildSliderTile(
                          context: context, title: 'Sustain Duration', subtitle: 'Time force must persist',
                          value: thresholds.turnDurationMs.toDouble(), defaultValue: SensorThresholdDefaults.turnDurationMs.toDouble(),
                          min: 100, max: 1500, divisions: 28, unit: 'ms', isDark: isDark,
                          onChanged: (v) => _updateThresholds(thresholds.copyWith(turnDurationMs: v.toInt())),
                        ),
                        _buildSliderTile(
                          context: context, title: 'Gyro Rotation Rate', subtitle: 'Min rotation to confirm turn',
                          value: thresholds.gyroRotationThreshold, defaultValue: SensorThresholdDefaults.gyroRotationThreshold,
                          min: 0.05, max: 1.5, divisions: 29, unit: 'rad/s', isDark: isDark,
                          onChanged: (v) => _updateThresholds(thresholds.copyWith(gyroRotationThreshold: v)),
                        ),
                      ],
                    ),
                    SizedBox(height: 15.h),

                    // Module: Turn Quality
                    _buildCalibrationModule(
                      context,
                      'TURN QUALITY SCORING',
                      Icons.analytics_rounded,
                      const Color(0xFF8B7CFF),
                      isDark,
                      [
                        _buildSliderTile(
                          context: context, title: 'Smooth Limit', subtitle: 'Force threshold for optimal turn',
                          value: thresholds.smoothTurnLimit, defaultValue: SensorThresholdDefaults.smoothTurnLimit,
                          min: 1.0, max: 6.0, divisions: 50, unit: 'm/s²', isDark: isDark,
                          onChanged: (v) => _updateThresholds(thresholds.copyWith(smoothTurnLimit: v)),
                        ),
                        _buildSliderTile(
                          context: context, title: 'Jerky Limit', subtitle: 'Force threshold for harsh turn',
                          value: thresholds.jerkyTurnLimit, defaultValue: SensorThresholdDefaults.jerkyTurnLimit,
                          min: 2.0, max: 10.0, divisions: 80, unit: 'm/s²', isDark: isDark,
                          onChanged: (v) => _updateThresholds(thresholds.copyWith(jerkyTurnLimit: v)),
                        ),
                        _buildSliderTile(
                          context: context, title: 'Speed Drop Delta', subtitle: 'Speed loss marking turn as harsh',
                          value: thresholds.significantSpeedDrop, defaultValue: SensorThresholdDefaults.significantSpeedDrop,
                          min: 3.0, max: 40.0, divisions: 37, unit: 'km/h', isDark: isDark,
                          onChanged: (v) => _updateThresholds(thresholds.copyWith(significantSpeedDrop: v)),
                        ),
                      ],
                    ),
                    SizedBox(height: 15.h),

                    // Module: Crash Detection
                    _buildCalibrationModule(
                      context,
                      'IMPACT DETECTION',
                      Icons.car_crash_rounded,
                      const Color(0xFFFF5252),
                      isDark,
                      [
                        _buildSliderTile(
                          context: context, title: 'Impact Accel Spike', subtitle: 'Jerk spike suspecting crash',
                          value: thresholds.crashAccelFluctuationLimit, defaultValue: SensorThresholdDefaults.crashAccelFluctuationLimit,
                          min: 0.2, max: 5.0, divisions: 48, unit: 'm/s²', isDark: isDark,
                          onChanged: (v) => _updateThresholds(thresholds.copyWith(crashAccelFluctuationLimit: v)),
                        ),
                        _buildSliderTile(
                          context: context, title: 'Rapid Deceleration', subtitle: 'Speed drop within 1.5s',
                          value: thresholds.crashSpeedDropLimit, defaultValue: SensorThresholdDefaults.crashSpeedDropLimit,
                          min: 5.0, max: 60.0, divisions: 55, unit: 'km/h', isDark: isDark,
                          onChanged: (v) => _updateThresholds(thresholds.copyWith(crashSpeedDropLimit: v)),
                        ),
                      ],
                    ),
                    SizedBox(height: 15.h),

                    // Module: Cooldowns
                    _buildCalibrationModule(
                      context,
                      'SYSTEM COOLDOWNS',
                      Icons.timer_rounded,
                      Colors.grey,
                      isDark,
                      [
                        _buildSliderTile(
                          context: context, title: 'Alert Cooldown', subtitle: 'Min time between event alerts',
                          value: thresholds.notificationCooldownSeconds.toDouble(), defaultValue: SensorThresholdDefaults.notificationCooldownSeconds.toDouble(),
                          min: 1, max: 30, divisions: 29, unit: 's', isDark: isDark,
                          onChanged: (v) => _updateThresholds(thresholds.copyWith(notificationCooldownSeconds: v.toInt())),
                        ),
                        _buildSliderTile(
                          context: context, title: 'Turn Cooldown', subtitle: 'Min time between turn triggers',
                          value: thresholds.turnCooldownSeconds.toDouble(), defaultValue: SensorThresholdDefaults.turnCooldownSeconds.toDouble(),
                          min: 1, max: 10, divisions: 9, unit: 's', isDark: isDark,
                          onChanged: (v) => _updateThresholds(thresholds.copyWith(turnCooldownSeconds: v.toInt())),
                        ),
                        _buildSliderTile(
                          context: context, title: 'Impact Cooldown', subtitle: 'Min time between crash triggers',
                          value: thresholds.crashCooldownSeconds.toDouble(), defaultValue: SensorThresholdDefaults.crashCooldownSeconds.toDouble(),
                          min: 5, max: 60, divisions: 55, unit: 's', isDark: isDark,
                          onChanged: (v) => _updateThresholds(thresholds.copyWith(crashCooldownSeconds: v.toInt())),
                        ),
                      ],
                    ),

                    // ─── RESET BUTTON ─────────────────────────
                    SizedBox(height: 15.h),
                    InkWell(
                      onTap: _resetThresholds,
                      borderRadius: BorderRadius.circular(16.r),
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16.r),
                          border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.restore_rounded, color: isDark ? Colors.white70 : Colors.black87, size: 20.r),
                            SizedBox(width: 8.w),
                            Text(
                              'RESTORE DEFAULT CALIBRATION',
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white70 : Colors.black87,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ── ACCESS CONTROL ───────────────────────────
                    SizedBox(height: 40.h),
                    _buildHudSectionHeader('ACCESS CONTROL', Icons.admin_panel_settings_rounded, const Color(0xFFFF5252), isDark),
                    SizedBox(height: 15.h),
                    _buildLogoutButton(context, auth, isDark),
                    SizedBox(height: 40.h),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // UI BUILDERS
  // ============================================================

  Widget _buildCustomAppBar(bool isDark) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 10.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SYSTEM CONFIGURATION',
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white54 : Colors.grey,
                    letterSpacing: 2,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'Settings & Calibration',
                  style: TextStyle(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF0A0E27),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.all(12.r),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF8B7CFF).withOpacity(0.1) : const Color(0xFF8B7CFF).withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF8B7CFF).withOpacity(0.3)),
            ),
            child: Icon(Icons.settings_suggest_rounded, color: const Color(0xFF8B7CFF), size: 24.r),
          ),
        ],
      ),
    );
  }

  Widget _buildHudSectionHeader(String title, IconData icon, Color accentColor, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 18.r, color: accentColor),
        SizedBox(width: 8.w),
        Text(
          title,
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : const Color(0xFF0A0E27),
            letterSpacing: 1.5,
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Container(
            height: 1.5,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [accentColor.withOpacity(0.5), Colors.transparent]),
            ),
          ),
        ),
      ],
    );
  }

  BoxDecoration _cardDecoration(BuildContext context, bool isDark) {
    return BoxDecoration(
      color: isDark ? const Color(0xFF1A1F3A) : Colors.white,
      borderRadius: BorderRadius.circular(24.r),
      border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10,
          offset: const Offset(0, 5),
        ),
      ],
    );
  }

  Widget _buildProfileHeader(BuildContext context, String name, bool isDark) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileManagement())),
      borderRadius: BorderRadius.circular(24.r),
      child: Container(
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1F3A) : Colors.white,
          borderRadius: BorderRadius.circular(24.r),
          border: Border.all(color: const Color(0xFF8B7CFF).withOpacity(0.3), width: 1.5),
          boxShadow: [
            BoxShadow(color: const Color(0xFF8B7CFF).withOpacity(0.1), blurRadius: 15, spreadRadius: 1),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(
                color: const Color(0xFF8B7CFF).withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF8B7CFF).withOpacity(0.5)),
              ),
              child: Icon(Icons.person_rounded, size: 28.r, color: const Color(0xFF8B7CFF)),
            ),
            SizedBox(width: 15.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.toUpperCase(),
                    style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    'Modify Access Credentials',
                    style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600, color: isDark ? Colors.white54 : Colors.grey),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 16.r, color: isDark ? Colors.white30 : Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    required Widget trailing,
    required bool isDark,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      leading: Container(
        padding: EdgeInsets.all(10.r),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14.r),
        ),
        child: Icon(icon, color: iconColor, size: 20.r),
      ),
      title: Text(
        title,
        style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87),
      ),
      subtitle: subtitle != null
          ? Padding(
        padding: EdgeInsets.only(top: 4.h),
        child: Text(subtitle, style: TextStyle(fontSize: 11.sp, color: isDark ? Colors.white54 : Colors.grey, fontWeight: FontWeight.w500)),
      )
          : null,
      trailing: trailing,
    );
  }

  Widget _buildEmergencyInputCard(bool isDark) {
    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFFFF5252).withOpacity(0.05) : const Color(0xFFFF5252).withOpacity(0.02),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: const Color(0xFFFF5252).withOpacity(0.5), width: 1.5),
        boxShadow: [
          BoxShadow(color: const Color(0xFFFF5252).withOpacity(0.1), blurRadius: 15),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.emergency_share_rounded, color: const Color(0xFFFF5252), size: 18.r),
              SizedBox(width: 8.w),
              Text(
                'EMERGENCY PROTOCOL',
                style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w900, color: const Color(0xFFFF5252), letterSpacing: 1),
              ),
            ],
          ),
          SizedBox(height: 15.h),
          buildTextField(context, emNumController, 'Contact Number (+92...)', () => setState(() {})),
          SizedBox(height: 15.h),
          SizedBox(
            width: double.infinity,
            height: 45.h,
            child: ElevatedButton(
              onPressed: saveEmergency,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5252),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
              ),
              child: Text('UPDATE CONTACT', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w900, letterSpacing: 1)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalibrationModule(BuildContext context, String title, IconData icon, Color accentColor, bool isDark, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1F3A) : Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: accentColor.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.08),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 16.r, color: accentColor),
                SizedBox(width: 8.w),
                Text(
                  title,
                  style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w900, color: accentColor, letterSpacing: 1),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 8.h),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildSliderTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required double value,
    required double defaultValue,
    required double min,
    required double max,
    required int divisions,
    required String unit,
    required ValueChanged<double> onChanged,
    required bool isDark,
  }) {
    final bool isDefault = (value - defaultValue).abs() < 0.001;
    final accentColor = const Color(0xFF00E5FF);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87)),
                    SizedBox(height: 2.h),
                    Text(subtitle, style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w500, color: isDark ? Colors.white54 : Colors.grey)),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(color: accentColor.withOpacity(0.3)),
                ),
                child: Text(
                  _formatValue(value, unit),
                  style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w900, color: accentColor),
                ),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6.r),
              overlayShape: RoundSliderOverlayShape(overlayRadius: 12.r),
              activeTrackColor: accentColor,
              inactiveTrackColor: isDark ? Colors.white10 : Colors.grey.shade200,
              thumbColor: accentColor,
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
          Row(
            children: [
              Icon(isDefault ? Icons.check_circle_rounded : Icons.info_outline_rounded, size: 12.r, color: isDefault ? const Color(0xFF4CAF50) : (isDark ? Colors.white30 : Colors.grey)),
              SizedBox(width: 4.w),
              Text(
                isDefault ? 'Factory Default' : 'Default: ${_formatValue(defaultValue, unit)}',
                style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w600, color: isDefault ? const Color(0xFF4CAF50) : (isDark ? Colors.white30 : Colors.grey)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatValue(double value, String unit) {
    final display = value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(2);
    return '$display $unit';
  }

  Widget _buildLogoutButton(BuildContext context, dynamic auth, bool isDark) {
    return InkWell(
      onTap: () => _showLogoutDialog(context, auth, isDark),
      borderRadius: BorderRadius.circular(24.r),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16.h),
        decoration: BoxDecoration(
          color: const Color(0xFFFF5252).withOpacity(0.1),
          borderRadius: BorderRadius.circular(24.r),
          border: Border.all(color: const Color(0xFFFF5252).withOpacity(0.3), width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.power_settings_new_rounded, color: const Color(0xFFFF5252), size: 20.r),
            SizedBox(width: 10.w),
            Text(
              'TERMINATE SESSION',
              style: TextStyle(color: const Color(0xFFFF5252), fontWeight: FontWeight.w900, fontSize: 13.sp, letterSpacing: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // LOGIC & DIALOGS
  // ============================================================

  void _updateThresholds(SensorThresholds updated) {
    ref.read(sensorThresholdsProvider.notifier).update(updated);
  }

  Future<void> _resetThresholds() async {
    await ref.read(sensorThresholdsProvider.notifier).reset();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('✅ Calibration Restored to Factory Settings', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFF4CAF50),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        ),
      );
    }
  }

  void _showStatusSnack(BuildContext context, bool enabled) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(enabled ? '✅ Impact Detection Online' : '⚠️ Impact Detection Offline', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: enabled ? const Color(0xFF4CAF50) : const Color(0xFFFF9800),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, dynamic auth, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A1F3A) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.r),
          side: BorderSide(color: const Color(0xFFFF5252).withOpacity(0.5)),
        ),
        title: Text(
          'TERMINATE SESSION',
          style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w900, color: const Color(0xFFFF5252), letterSpacing: 1.5),
        ),
        content: Text(
          'Are you sure you want to disconnect from the RAXXY network?',
          style: TextStyle(fontSize: 13.sp, color: isDark ? Colors.white70 : Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('CANCEL', style: TextStyle(color: isDark ? Colors.white54 : Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              await auth.signOut();
              if (context.mounted) Navigator.of(ctx).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5252).withOpacity(0.2),
              foregroundColor: const Color(0xFFFF5252),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
            ),
            child: const Text('DISCONNECT', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  bool phoneValidator(String? value) {
    if (value == null || value.isEmpty) return false;
    return RegExp(r'^\+92\d{10}$').hasMatch(value);
  }

  Future<void> saveEmergency() async {
    final auth = ref.read(firebaseAuthProvider);
    final firestore = FirebaseFirestore.instance;
    final userDoc = firestore.collection('users').doc(auth.currentUser!.uid);
    final prefs = ref.read(sharedPreferencesProvider);
    final phone = emNumController.text.trim();

    if (phoneValidator(phone)) {
      try {
        await userDoc.set({'emergencyContact': phone}, SetOptions(merge: true));
        await prefs.setString('emergency_contact', phone);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: const Text('✅ Protocol Updated'), backgroundColor: const Color(0xFF4CAF50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)), behavior: SnackBarBehavior.floating),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: const Text('❌ System Error: Cannot Update Protocol'), backgroundColor: const Color(0xFFFF5252), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)), behavior: SnackBarBehavior.floating),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('⚠️ Invalid Format: Requires +92XXXXXXXXXX'), backgroundColor: const Color(0xFFFF9800), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }
}