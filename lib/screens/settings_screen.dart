import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:persistent_bottom_nav_bar/persistent_bottom_nav_bar.dart';
import 'package:raxxy/screens/settings_subscreens/user_management.dart';
import '../providers/provider.dart';
import '../providers/safety_feature_provider.dart';
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
    String? emergencyContact = prefs.getString('emergency_contact');
    if (emergencyContact != null) {
      emNumController.text = emergencyContact;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.read(firebaseAuthProvider);
    final username = auth.currentUser?.displayName ?? 'Driver';
    final themeMode = ref.watch(themeNotifierProvider);
    final crash = ref.watch(featureNotifierProvider);
    final isDark = themeMode == ThemeMode.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24.sp)),
          ],
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xff6a11cb), Color(0xff2575fc)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),

            boxShadow: [
              BoxShadow(
                color: const Color(0xff2575fc).withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 10.h),

              // --- PROFILE HEADER ---
              _buildProfileHeader(context, username),

              SizedBox(height: 30.h),
              _sectionLabel("App Preferences"),

              // --- PREFERENCES GROUP ---
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(24.r),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                  ),
                ),
                child: Column(
                  children: [
                    _buildSettingTile(
                      icon: isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                      iconColor: Colors.amber,
                      title: "Dark Mode",
                      trailing: Switch.adaptive(
                        value: isDark,
                        onChanged: (val) {
                          ref.read(themeNotifierProvider.notifier).toggleTheme();
                        },
                      ),
                    ),
                    Divider(height: 1, indent: 60.w, endIndent: 20.w),
                    _buildSettingTile(
                      icon: Icons.security_rounded,
                      iconColor: Colors.blueAccent,
                      title: "Crash Detection",
                      subtitle: crash ? "Monitoring Active" : "Disabled",
                      trailing: Switch.adaptive(
                        value: crash,
                        activeColor: Colors.greenAccent,
                        onChanged: (val) {
                          ref.read(featureNotifierProvider.notifier).togglefeature();
                          _showStatusSnack(context, val);
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // --- EMERGENCY CONTACT SECTION (ANIMATED) ---
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: crash
                    ? Padding(
                  padding: EdgeInsets.only(top: 15.h),
                  child: _buildEmergencyInputCard(),
                )
                    : const SizedBox.shrink(),
              ),

              SizedBox(height: 30.h),
              _sectionLabel("Voice Coach Settings"),

              // --- VOICE COACH BUTTONS ---
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(24.r),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                  ),
                ),
                child: Column(
                  children: [
                    _buildActionTile(
                      icon: Icons.play_arrow_rounded,
                      iconColor: Colors.green,
                      title: "Test Voice",
                      subtitle: "Preview selected voice",
                      onTap: _testVoice,
                    ),
                  ],
                ),
              ),

              SizedBox(height: 30.h),
              _sectionLabel("Account Management"),

              // --- LOGOUT BUTTON ---
              _buildLogoutButton(context, auth),

              SizedBox(height: 40.h),
            ],
          ),
        ),
      ),
    );
  }

  // Helper: Section Labels
  Widget _sectionLabel(String label) {
    return Padding(
      padding: EdgeInsets.only(left: 8.w, bottom: 10.h),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 12.sp,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  // Helper: Profile Header
  Widget _buildProfileHeader(BuildContext context, String name) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ProfileManagement()),
      ),
      borderRadius: BorderRadius.circular(24.r),
      child: Container(
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(24.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30.r,
              backgroundColor: const Color(0xffb2b0ff).withOpacity(0.2),
              child: Icon(Icons.person_rounded, size: 35.r, color: const Color(0xffb2b0ff)),
            ),
            SizedBox(width: 15.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
                  ),
                  Text("Edit account details", style: TextStyle(fontSize: 13.sp, color: Colors.grey)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  // Helper: Settings Tile
  Widget _buildSettingTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    required Widget trailing,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
      leading: Container(
        padding: EdgeInsets.all(8.r),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Icon(icon, color: iconColor, size: 22.r),
      ),
      title: Text(title, style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600)),
      subtitle: subtitle != null
          ? Text(subtitle, style: TextStyle(fontSize: 12.sp, color: Colors.grey))
          : null,
      trailing: trailing,
    );
  }

  // Helper: Action Tile (like settings tile but with onTap)
  Widget _buildActionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
      leading: Container(
        padding: EdgeInsets.all(8.r),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Icon(icon, color: iconColor, size: 22.r),
      ),
      title: Text(title, style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600)),
      subtitle: subtitle != null
          ? Text(subtitle, style: TextStyle(fontSize: 12.sp, color: Colors.grey))
          : null,
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
      onTap: onTap,
    );
  }

  // Helper: Emergency Input Card
  Widget _buildEmergencyInputCard() {
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          buildTextField(
            context,
            emNumController,
            "Emergency Contact (+92...)",
                () => setState(() {}),
          ),
          SizedBox(height: 12.h),
          SizedBox(
            width: double.infinity,
            height: 45.h,
            child: ElevatedButton(
              onPressed: saveEmergency,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent.withOpacity(0.1),
                foregroundColor: Colors.redAccent,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
              ),
              child: const Text("Save Emergency Contact", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // Helper: Logout Button
  Widget _buildLogoutButton(BuildContext context, dynamic auth) {
    return InkWell(
      onTap: () => _showLogoutDialog(context, auth),
      borderRadius: BorderRadius.circular(20.r),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16.h),
        decoration: BoxDecoration(
          color: const Color(0xFF8A2E3B).withOpacity(0.1),
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: const Color(0xFF8A2E3B).withOpacity(0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.logout_rounded, color: Color(0xFF8A2E3B)),
            SizedBox(width: 10.w),
            Text(
              "Logout Account",
              style: TextStyle(
                color: const Color(0xFF8A2E3B),
                fontWeight: FontWeight.bold,
                fontSize: 16.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showStatusSnack(BuildContext context, bool enabled) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(enabled ? "Crash Detection Enabled" : "Crash Detection Disabled"),
        backgroundColor: enabled ? Colors.green.shade700 : Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(20.r),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, dynamic auth) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        title: const Text("Logout?"),
        content: const Text("Are you sure you want to end your session?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              await auth.signOut();
              if (context.mounted) Navigator.of(ctx).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8A2E3B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
            ),
            child: const Text("Logout", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- NEW VOICE METHODS ---

  // Replace the _showVoiceSelectionDialog method with this fixed version:


  Future<void> _testVoice() async {
    await _coachingService.testVoice();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("🎤 Testing voice..."),
        backgroundColor: Colors.blue.shade700,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(20.r),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      ),
    );
  }

  // --- LOGIC METHODS ---

  bool phoneValidator(String? value) {
    if (value == null || value.isEmpty) return false;
    final regex = RegExp(r'^\+92\d{10}$');
    return regex.hasMatch(value);
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
            const SnackBar(content: Text("✅ Emergency contact saved!"), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("❌ Error saving contact")),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("⚠️ Format: +92XXXXXXXXXX")),
        );
      }
    }
  }
}