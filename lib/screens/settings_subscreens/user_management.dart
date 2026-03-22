import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../providers/provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/reusable_widgets.dart';

class ProfileManagement extends ConsumerStatefulWidget {
  const ProfileManagement({super.key});

  @override
  ConsumerState<ProfileManagement> createState() => _ProfileManagementState();
}

class _ProfileManagementState extends ConsumerState<ProfileManagement> {
  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(firebaseAuthProvider);
    final themeMode = ref.watch(themeNotifierProvider);
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);

    final currentUser = auth.currentUser;
    final currentName = currentUser?.displayName ?? 'Unknown Pilot';
    final currentEmail = currentUser?.email ?? 'No email linked';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0E27) : const Color(0xFFF4F5F9),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── CUSTOM HEADER ──────────────────────────────
            _buildCustomHeader(context, isDark),

            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 10.h),

                    // ── CURRENT IDENTITY CARD ────────────────
                    _buildHudSectionHeader('CURRENT IDENTITY', Icons.fingerprint_rounded, const Color(0xFF00E5FF), isDark),
                    SizedBox(height: 15.h),
                    _buildCurrentProfileCard(currentName, currentEmail, isDark),

                    SizedBox(height: 35.h),

                    // ── MODIFICATION ACTIONS ─────────────────
                    _buildHudSectionHeader('CREDENTIAL MODIFICATION', Icons.admin_panel_settings_rounded, const Color(0xFF8B7CFF), isDark),
                    SizedBox(height: 15.h),

                    _buildActionTile(
                      title: "UPDATE DISPLAY NAME",
                      icon: Icons.badge_rounded,
                      accentColor: const Color(0xFF00E5FF),
                      isDark: isDark,
                      onTap: () => _showChangeNameDialog(context, ref, currentName, isDark),
                    ),
                    SizedBox(height: 12.h),

                    _buildActionTile(
                      title: "REQUEST PASSWORD RESET",
                      icon: Icons.lock_reset_rounded,
                      accentColor: const Color(0xFFFF9800),
                      isDark: isDark,
                      onTap: () => _confirmPasswordReset(context, ref, isDark),
                    ),

                    SizedBox(height: 40.h),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // UI BUILDERS
  // ============================================================

  Widget _buildCustomHeader(BuildContext context, bool isDark) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 15.h),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: EdgeInsets.all(10.r),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                shape: BoxShape.circle,
                border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
              ),
              child: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white70 : Colors.black87, size: 20.r),
            ),
          ),
          SizedBox(width: 15.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ACCESS CONTROL',
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white54 : Colors.grey,
                    letterSpacing: 2,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'Profile Management',
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

  Widget _buildCurrentProfileCard(String name, String email, bool isDark) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1F3A) : Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(color: const Color(0xFF00E5FF).withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(15.r),
            decoration: BoxDecoration(
              color: const Color(0xFF00E5FF).withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.5)),
            ),
            child: Icon(Icons.person_rounded, size: 30.r, color: const Color(0xFF00E5FF)),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.toUpperCase(),
                  style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4.h),
                Text(
                  email,
                  style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: isDark ? Colors.white54 : Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required String title,
    required IconData icon,
    required Color accentColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
        decoration: BoxDecoration(
          color: isDark ? accentColor.withOpacity(0.05) : accentColor.withOpacity(0.02),
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: accentColor.withOpacity(0.3), width: 1.5),
          boxShadow: [
            BoxShadow(color: accentColor.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: accentColor, size: 24.r),
            SizedBox(width: 15.w),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                  letterSpacing: 1,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: accentColor.withOpacity(0.5), size: 16.r),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // LOGIC & DIALOGS
  // ============================================================

  void _showChangeNameDialog(BuildContext context, WidgetRef ref, String currentName, bool isDark) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A1F3A) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.r),
          side: BorderSide(color: const Color(0xFF00E5FF).withOpacity(0.5)),
        ),
        title: Text(
          "UPDATE DISPLAY NAME",
          style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w900, color: const Color(0xFF00E5FF), letterSpacing: 1.5),
        ),
        content: TextField(
          controller: controller,
          style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            hintText: "Enter new pilot designation",
            hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.black26, fontSize: 13.sp),
            filled: true,
            fillColor: isDark ? const Color(0xFF0A0E27) : Colors.grey.shade100,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16.r), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16.r), borderSide: const BorderSide(color: Color(0xFF00E5FF), width: 2)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("CANCEL", style: TextStyle(color: isDark ? Colors.white54 : Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              final auth = ref.read(firebaseAuthProvider);
              if (controller.text.trim().isNotEmpty && controller.text.trim() != currentName) {
                await auth.currentUser?.updateDisplayName(controller.text.trim());
                await auth.currentUser?.reload();
                if (context.mounted) {
                  Navigator.pop(ctx);
                  setState(() {}); // refresh UI
                  _showSuccessSnack("Display name updated successfully", const Color(0xFF00E5FF));
                }
              } else {
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E5FF).withOpacity(0.2),
              foregroundColor: const Color(0xFF00E5FF),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
            ),
            child: const Text("SAVE CHANGES", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showChangeEmailDialog(BuildContext context, WidgetRef ref, String currentEmail, bool isDark) {
    final controller = TextEditingController(text: currentEmail);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A1F3A) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.r),
          side: BorderSide(color: const Color(0xFF8B7CFF).withOpacity(0.5)),
        ),
        title: Text(
          "UPDATE EMAIL ADDRESS",
          style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w900, color: const Color(0xFF8B7CFF), letterSpacing: 1.5),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            hintText: "Enter new email address",
            hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.black26, fontSize: 13.sp),
            filled: true,
            fillColor: isDark ? const Color(0xFF0A0E27) : Colors.grey.shade100,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16.r), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16.r), borderSide: const BorderSide(color: Color(0xFF8B7CFF), width: 2)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("CANCEL", style: TextStyle(color: isDark ? Colors.white54 : Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              final auth = ref.read(firebaseAuthProvider);
              if (controller.text.trim().isNotEmpty && controller.text.trim() != currentEmail) {
                try {
                  await auth.currentUser?.updateEmail(controller.text.trim());
                  await auth.currentUser?.reload();
                  if (context.mounted) {
                    Navigator.pop(ctx);
                    setState(() {});
                    _showSuccessSnack("Email address updated successfully", const Color(0xFF8B7CFF));
                  }
                } catch (e) {
                  if (context.mounted) {
                    Navigator.pop(ctx);
                    showAppSnackBar(
                      context,
                      "Error: ${e.toString()}",
                      backgroundColor: const Color(0xFFFF5252),
                    );
                  }
                }
              } else {
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B7CFF).withOpacity(0.2),
              foregroundColor: const Color(0xFF8B7CFF),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
            ),
            child: const Text("SAVE CHANGES", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmPasswordReset(BuildContext context, WidgetRef ref, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A1F3A) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.r),
          side: BorderSide(color: const Color(0xFFFF9800).withOpacity(0.5)),
        ),
        title: Text(
          "RESET PASSWORD",
          style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w900, color: const Color(0xFFFF9800), letterSpacing: 1.5),
        ),
        content: Text(
          "Are you sure you want to request a password reset? An email will be sent to your registered address with instructions.",
          style: TextStyle(fontSize: 13.sp, color: isDark ? Colors.white70 : Colors.black87, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("CANCEL", style: TextStyle(color: isDark ? Colors.white54 : Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              final auth = ref.read(firebaseAuthProvider);
              final email = auth.currentUser?.email;
              Navigator.pop(ctx); // Close dialog immediately

              if (email != null) {
                try {
                  await auth.sendPasswordResetEmail(email: email);
                  if (context.mounted) {
                    _showSuccessSnack("Recovery link transmitted to $email", const Color(0xFFFF9800));
                  }
                } catch (e) {
                  if (context.mounted) {
                    showAppSnackBar(
                      context,
                      "Transmission Error: $e",
                      backgroundColor: const Color(0xFFFF5252),
                    );
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF9800).withOpacity(0.2),
              foregroundColor: const Color(0xFFFF9800),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
            ),
            child: const Text("TRANSMIT LINK", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showSuccessSnack(String message, Color accentColor) {
    showAppSnackBar(
      context,
      "✅ $message",
      backgroundColor: accentColor,
    );
  }
}