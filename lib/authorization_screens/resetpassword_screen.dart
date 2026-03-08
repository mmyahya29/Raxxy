import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:raxxy/main.dart';
import 'package:raxxy/providers/provider.dart';
import 'package:raxxy/providers/theme_provider.dart';

import '../widgets/reusable_widgets.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> with SingleTickerProviderStateMixin {
  final emailController = TextEditingController();

  final auth = FirebaseAuth.instance;
  final firestore = FirebaseFirestore.instance;

  bool isLoading = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000), // Matched to smooth boot animation
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    emailController.dispose();
    super.dispose();
  }

  Future<void> resetPassword() async {
    final authProvider = ref.read(firebaseAuthProvider);
    final email = emailController.text.trim();

    if (email.isEmpty) {
      _showSystemSnack("MISSING PARAMETER: Pilot email required", const Color(0xFFFF9800));
      return;
    }

    if (emailValidator(email)) {
      try {
        setState(() => isLoading = true);
        await authProvider.sendPasswordResetEmail(email: email);

        if (mounted) {
          setState(() => isLoading = false);
          _showSystemSnack("TRANSMISSION SUCCESS: Recovery link dispatched", const Color(0xFF00E5FF));
          emailController.clear();
        }
      } catch (e) {
        if (mounted) {
          setState(() => isLoading = false);
          _showSystemSnack("TRANSMISSION FAILED: ${e.toString()}", const Color(0xFFFF5252));
        }
      }
    } else {
      _showSystemSnack("INVALID PROTOCOL: Check email format", const Color(0xFFFF5252));
    }
  }

  void _showSystemSnack(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.terminal_rounded, color: Colors.white, size: 20.r),
            SizedBox(width: 10.w),
            Expanded(
              child: Text(
                message.toUpperCase(),
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.sp, letterSpacing: 1),
              ),
            ),
          ],
        ),
        backgroundColor: color.withOpacity(0.95),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        margin: EdgeInsets.all(20.r),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeNotifierProvider);
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0E27) : const Color(0xFFF4F5F9),
      body: buildAuth(isDark),
    );
  }

  Widget buildAuth(bool isDark) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: isDark
            ? const RadialGradient(
                colors: [Color(0xFF1E2447), Color(0xFF0A0E27)],
                radius: 1.5,
                center: Alignment.topCenter,
              )
            : const LinearGradient(
                colors: [Color(0xFFF4F5F9), Color(0xFFE8EAF6)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(height: 60.h),

                    // ── LOGO HUD ──────────────────────────────────────────
                    Container(
                      height: 110.r,
                      width: 110.r,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF0A0E27),
                        border: Border.all(color: const Color(0xFFFF9800).withOpacity(0.5), width: 2), // Orange warning tint
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF9800).withOpacity(0.3),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(20.r),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/raxxy_icon1.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 30.h),

                    // ── TITLE ──────────────────────────────────────────────
                    Text(
                      'REST PASSWORD',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 24.sp,
                        color: Colors.white,
                        letterSpacing: 2,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.w),
                      child: Text(
                        'Provide your email to receive a secure reset link',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 12.sp,
                          color: const Color(0xFFFF9800).withOpacity(0.8),
                          letterSpacing: 0.5,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    SizedBox(height: 40.h),

                    // ── RECOVERY CARD ──────────────────────────────────────
                    Container(
                      padding: EdgeInsets.all(24.r),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(30.r),
                        border: Border.all(color: const Color(0xFFFF9800).withOpacity(0.3), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Email Field
                          _buildInputLabel(Icons.fingerprint_rounded, 'REGISTERED EMAIL'),
                          SizedBox(height: 8.h),
                          buildTextField(
                            context,
                            emailController,
                            'someone@example.com',
                                () => setState(() {}),
                          ),
                          SizedBox(height: 35.h),

                          // ── RESET BUTTON ──────────────────────────────────
                          SizedBox(
                            width: double.infinity,
                            height: 55.h,
                            child: isLoading
                                ? Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF9800).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16.r),
                                border: Border.all(color: const Color(0xFFFF9800).withOpacity(0.5)),
                              ),
                              child: const Center(
                                child: SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    color: Color(0xFFFF9800),
                                    strokeWidth: 3,
                                  ),
                                ),
                              ),
                            )
                                : ElevatedButton(
                              onPressed: resetPassword,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                                elevation: 0,
                              ),
                              child: Ink(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFFF5252), Color(0xFFFF9800)], // Alert gradient
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(16.r),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFFF9800).withOpacity(0.4),
                                      blurRadius: 15,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: Container(
                                  alignment: Alignment.center,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.satellite_alt_rounded, color: Colors.white, size: 20.r),
                                      SizedBox(width: 10.w),
                                      Text(
                                        'SEND RESET LINK',
                                        style: TextStyle(
                                          fontSize: 12.sp,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 30.h),

                    // ── OR DIVIDER ──────────────────────────────────────────
                    Row(
                      children: [
                        Expanded(child: Divider(color: const Color(0xFFFF9800).withOpacity(0.3), thickness: 1)),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 15.w),
                          child: Text(
                            'CANCEL?',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: const Color(0xFFFF9800).withOpacity(0.3), thickness: 1)),
                      ],
                    ),
                    SizedBox(height: 30.h),

                    // ── RETURN BUTTON ──────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 55.h,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => const MyApp()),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: const Color(0xFF8B7CFF).withOpacity(0.5), width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                          backgroundColor: const Color(0xFF8B7CFF).withOpacity(0.05),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.arrow_back_rounded, color: const Color(0xFF8B7CFF), size: 20.r),
                            SizedBox(width: 10.w),
                            Text(
                              'RETURN TO LOGIN',
                              style: TextStyle(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF8B7CFF),
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 30.h),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- Helper for Input Labels ---
  Widget _buildInputLabel(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16.r, color: const Color(0xFFFF9800)),
        SizedBox(width: 8.w),
        Text(
          text,
          style: TextStyle(
            fontSize: 10.sp,
            fontWeight: FontWeight.w800,
            color: const Color(0xFFFF9800),
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }
}