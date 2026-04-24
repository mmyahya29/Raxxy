import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:raxxy/providers/provider.dart';
import 'package:raxxy/providers/theme_provider.dart';

import '../main.dart';
import '../widgets/reusable_widgets.dart';
import 'login_screen.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> with SingleTickerProviderStateMixin {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmpasswordController = TextEditingController();

  // NEW: Age and Guardian controllers
  final ageController = TextEditingController();
  final guardianController = TextEditingController();

  bool pashid = true;
  bool cpashid = true;

  bool isLoading = false;

  // NEW: Track if user is a minor
  bool isTeenager = false;

  final firestore = FirebaseFirestore.instance;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000), // Matched to login screen's smooth boot
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

    // NEW: Listen to age input to show/hide guardian field
    ageController.addListener(() {
      final ageText = ageController.text.trim();
      if (ageText.isNotEmpty) {
        final age = int.tryParse(ageText);
        if (age != null) {
          setState(() {
            isTeenager = age < 18;
          });
        }
      } else {
        setState(() {
          isTeenager = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmpasswordController.dispose();
    ageController.dispose();
    guardianController.dispose();
    super.dispose();
  }

  bool phoneValidator(String? value) {
    if (value == null || value.isEmpty) return false;
    return RegExp(r'^\+92\d{10}$').hasMatch(value);
  }

  Future<void> signup() async {
    final auth = ref.read(firebaseAuthProvider);
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final cpassword = confirmpasswordController.text.trim();
    final password = passwordController.text.trim();
    final ageText = ageController.text.trim();
    final guardianPhone = guardianController.text.trim();

    // NEW: Validate Age
    if (ageText.isEmpty) {
      showError("MISSING DATA: Please enter your age");
      return;
    }

    final age = int.tryParse(ageText);
    if (age == null || age < 16) {
      showError("ACCESS DENIED: Minimum age requirement is 16");
      return;
    }

    // NEW: Validate Guardian Phone if teenager
    if (isTeenager && !phoneValidator(guardianPhone)) {
      showError("INVALID FORMAT: Guardian number requires +92XXXXXXXXXX");
      return;
    }

    if (emailValidator(email)) {
      if (password == cpassword && password != "" && cpassword != "") {
        try {
          setState(() {
            isLoading = true;
          });
          await auth.createUserWithEmailAndPassword(email: email, password: password);
          final user = auth.currentUser;

          if (user != null) {
            await user.updateDisplayName(name);
            await user.reload();

            // Save to Firestore
            Map<String, dynamic> userData = {
              'email': user.email,
              'name': name,
              'age': age,
              'createdAt': FieldValue.serverTimestamp(),
            };

            // Only save guardian contact if they are a minor
            if (isTeenager) {
              userData['guardianContact'] = guardianPhone;
            }

            await firestore.collection('users').doc(user.uid).set(userData);

            if (mounted) {
              _showSystemSnack("REGISTERED: Access granted", const Color(0xFF00E5FF));
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const MyApp()),
              );
            }
          }
        } on FirebaseAuthException catch (e) {
          setState(() {
            isLoading = false;
          });
          String? mess = getErrorMessage(e.code);
          showError(mess ?? "UNKNOWN AUTHENTICATION ERROR");
        }
      } else {
        showError("MISMATCH: Passwords do not align");
      }
    } else {
      showError("INVALID EMAIL: Check email format");
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
                    SizedBox(height: 40.h),

                    // ── LOGO HUD ──────────────────────────────────────────
                    Container(
                      height: 100.r,
                      width: 100.r,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF0A0E27),
                        border: Border.all(color: const Color(0xFF8B7CFF).withOpacity(0.5), width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF8B7CFF).withOpacity(0.3),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(18.r),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/raxxy_icon1.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 25.h),

                    // ── TITLE ──────────────────────────────────────────────
                    Text(
                      'REGISTRATION',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 26.sp,
                        color: Colors.white,
                        letterSpacing: 2,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      'Create a New Driver',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 13.sp,
                        color: const Color(0xFF8B7CFF).withOpacity(0.8),
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 35.h),

                    // ── AUTHENTICATION CARD ────────────────────────────────
                    Container(
                      padding: EdgeInsets.all(24.r),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(30.r),
                        border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.3), width: 1.5),
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
                          // Name Field
                          _buildInputLabel(Icons.badge_outlined, 'NAME'),
                          SizedBox(height: 8.h),
                          buildTextField(context, nameController, 'Enter name', () => setState(() {})),
                          SizedBox(height: 16.h),

                          // Email Field
                          _buildInputLabel(Icons.fingerprint_rounded, 'EMAIL'),
                          SizedBox(height: 8.h),
                          buildTextField(context, emailController, 'someone@example.com', () => setState(() {})),
                          SizedBox(height: 16.h),

                          // NEW: Age Field
                          _buildInputLabel(Icons.cake_outlined, 'AGE'),
                          SizedBox(height: 8.h),
                          buildTextField(context, ageController, 'Enter your age', () => setState(() {}), inputType: TextInputType.number),
                          SizedBox(height: 16.h),

                          // NEW: Dynamic Guardian Field (Only shows if age < 18)
                          AnimatedSize(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            child: isTeenager
                                ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.family_restroom_rounded, size: 16.r, color: const Color(0xFFFF9800)),
                                    SizedBox(width: 8.w),
                                    Text(
                                      'GUARDIAN CONTACT (REQUIRED FOR MINORS)',
                                      style: TextStyle(
                                        fontSize: 10.sp,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFFFF9800),
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8.h),
                                buildTextField(context, guardianController, '+92XXXXXXXXXX', () => setState(() {}), inputType: TextInputType.phone),
                                SizedBox(height: 16.h),
                              ],
                            )
                                : const SizedBox.shrink(),
                          ),

                          // Password Field
                          _buildInputLabel(Icons.lock_outline_rounded, 'PASSWORD'),
                          SizedBox(height: 8.h),
                          buildTextField(
                            context,
                            passwordController,
                            'Create password',
                                () => setState(() => pashid = !pashid),
                            obscure: pashid,
                            pass: true,
                          ),
                          SizedBox(height: 16.h),

                          // Confirm Password Field
                          _buildInputLabel(Icons.verified_user_outlined, 'CONFIRM PASSWORD'),
                          SizedBox(height: 8.h),
                          buildTextField(
                            context,
                            confirmpasswordController,
                            'Re-enter password',
                                () => setState(() => cpashid = !cpashid),
                            obscure: cpashid,
                            pass: true,
                          ),
                          SizedBox(height: 35.h),

                          // ── SIGNUP BUTTON ──────────────────────────────────
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
                              onPressed: signup,
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
                                      Icon(Icons.how_to_reg_rounded, color: Colors.white, size: 20.r),
                                      SizedBox(width: 10.w),
                                      Text(
                                        'REGISTER',
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
                        Expanded(child: Divider(color: const Color(0xFF00E5FF).withOpacity(0.3), thickness: 1)),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 15.w),
                          child: Text(
                            'ALREADY REGISTERED?',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: const Color(0xFF00E5FF).withOpacity(0.3), thickness: 1)),
                      ],
                    ),
                    SizedBox(height: 30.h),

                    // ── LOGIN BUTTON ──────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 55.h,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => const LoginScreen()),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: const Color(0xFF00E5FF).withOpacity(0.5), width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                          backgroundColor: const Color(0xFF00E5FF).withOpacity(0.05),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.login_rounded, color: const Color(0xFF00E5FF), size: 20.r),
                            SizedBox(width: 10.w),
                            Text(
                              'ALREADY A DRIVER? LOGIN',
                              style: TextStyle(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF00E5FF),
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