import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:raxxy/authorization_screens/resetpassword_screen.dart';
import 'package:raxxy/authorization_screens/signup_screen.dart';
import 'package:raxxy/providers/provider.dart';
import 'package:raxxy/providers/theme_provider.dart';

import '../bottom_nav_bar.dart';
import '../widgets/reusable_widgets.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> with SingleTickerProviderStateMixin {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool pashid = true;
  bool isLoading = false;

  final auth = FirebaseAuth.instance;
  final firestore = FirebaseFirestore.instance;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000), // Slightly longer for a smoother boot-up feel
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1), // Shorter slide for a more premium feel
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
    passwordController.dispose();
    super.dispose();
  }

  Future<void> authenticate() async {
    final authProvider = ref.read(firebaseAuthProvider);
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (emailValidator(email)) {
      try {
        setState(() {
          isLoading = true;
        });
        await authProvider.signInWithEmailAndPassword(email: email, password: password);

        if (mounted) {
          _showSystemSnack("ACCESS GRANTED: Connection Established", const Color(0xFF00E5FF));

          // 🚨 THE MISSING NAVIGATION PIECE 🚨
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const PersistentNavWrapper()), // Or PersistentNavWrapper(), depending on your main routing
          );
        }
      } on FirebaseAuthException catch (e) {
        setState(() {
          isLoading = false;
        });
        String? mess = getErrorMessage(e.code);
        showError(mess ?? "UNKNOWN AUTHENTICATION ERROR");
      }
    } else {
      showError("INVALID PROTOCOL: Check email format");
    }
  }

  void showError(String message) {
    _showSystemSnack("ACCESS DENIED: $message", const Color(0xFFFF5252));
  }

  void _showSystemSnack(String message, Color color) {
    showAppSnackBar(
      context,
      message,
      backgroundColor: color,
      icon: Icons.terminal_rounded,
      terminalStyle: true,
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
                        border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.5), width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00E5FF).withOpacity(0.3),
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
                      'SYSTEM LOGIN',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 28.sp,
                        color: Colors.white,
                        letterSpacing: 3,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      'Authenticate to access',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 13.sp,
                        color: const Color(0xFF00E5FF).withOpacity(0.8),
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 40.h),

                    // ── AUTHENTICATION CARD ────────────────────────────────
                    Container(
                      padding: EdgeInsets.all(24.r),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(30.r),
                        border: Border.all(color: const Color(0xFF8B7CFF).withOpacity(0.3), width: 1.5),
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
                          _buildInputLabel(Icons.fingerprint_rounded, 'EMAIL'),
                          SizedBox(height: 8.h),
                          buildTextField(
                            context,
                            emailController,
                            'someone@example.com',
                                () => setState(() {}),
                          ),
                          SizedBox(height: 20.h),

                          // Password Field
                          _buildInputLabel(Icons.lock_outline_rounded, 'PASSWORD'),
                          SizedBox(height: 8.h),
                          buildTextField(
                            context,
                            passwordController,
                            '••••••••',
                                () => setState(() {
                              pashid = !pashid;
                            }),
                            obscure: pashid,
                            pass: true,
                          ),
                          SizedBox(height: 35.h),

                          // ── LOGIN BUTTON ──────────────────────────────────
                          SizedBox(
                            width: double.infinity,
                            height: 55.h,
                            child: isLoading
                                ? Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF00E5FF).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16.r),
                                border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.5)),
                              ),
                              child: const Center(
                                child: SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    color: Color(0xFF00E5FF),
                                    strokeWidth: 3,
                                  ),
                                ),
                              ),
                            )
                                : ElevatedButton(
                              onPressed: authenticate,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                                elevation: 0,
                              ),
                              child: Ink(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF8B7CFF), Color(0xFF00E5FF)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(16.r),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF00E5FF).withOpacity(0.4),
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
                                      Icon(Icons.login_rounded, color: Colors.white, size: 20.r),
                                      SizedBox(width: 10.w),
                                      Text(
                                        'AUTHORIZE',
                                        style: TextStyle(
                                          fontSize: 13.sp,
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
                        Expanded(child: Divider(color: const Color(0xFF8B7CFF).withOpacity(0.3), thickness: 1)),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 15.w),
                          child: Text(
                            'UNREGISTERED?',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: const Color(0xFF8B7CFF).withOpacity(0.3), thickness: 1)),
                      ],
                    ),
                    SizedBox(height: 30.h),

                    // ── SIGN UP BUTTON ──────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 55.h,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => const SignupScreen()),
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
                            Icon(Icons.person_add_alt_1_rounded, color: const Color(0xFF8B7CFF), size: 20.r),
                            SizedBox(width: 10.w),
                            Text(
                              'REGISTER NEW',
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
                    SizedBox(height: 10.h),

                    // ── FORGOT PASSWORD LINK ────────────────────────────────
                    TextButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const ResetPasswordScreen()),
                        );
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 15.h),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.vpn_key_outlined, size: 16.r, color: Colors.white54),
                          SizedBox(width: 8.w),
                          Text(
                            'REQUEST CREDENTIAL RESET',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
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
        Icon(icon, size: 16.r, color: const Color(0xFF8B7CFF)),
        SizedBox(width: 8.w),
        Text(
          text,
          style: TextStyle(
            fontSize: 10.sp,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF8B7CFF),
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }
}