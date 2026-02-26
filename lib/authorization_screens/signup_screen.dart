import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:raxxy/providers/provider.dart';

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

  bool pashid = true;
  bool cpashid = true;

  bool isLoading = false;

  final firestore = FirebaseFirestore.instance;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmpasswordController.dispose();
    super.dispose();
  }

  Future<void> signup() async {
    final auth = ref.read(firebaseAuthProvider);
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final cpassword = confirmpasswordController.text.trim();
    final password = passwordController.text.trim();

    if (emailValidator(email)) {
      if (password == cpassword && password != "" && cpassword != "") {
        try {
          setState(() {
            isLoading = true;
          });
          await auth.createUserWithEmailAndPassword(
              email: email, password: password);
          final user = auth.currentUser;

          if (user != null) {
            await user.updateDisplayName(name);
            await user.reload();

            // Save to Firestore
            await firestore.collection('users').doc(user.uid).set({
              'email': user.email,
              'name': name,
              'createdAt': FieldValue.serverTimestamp(),
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 10.w),
                    Text("Account Created Successfully"),
                  ],
                ),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 3),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
              ),
            );
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const MyApp()),
            );
          }
        } on FirebaseAuthException catch (e) {
          setState(() {
            isLoading = false;
          });
          String? mess = getErrorMessage(e.code);
          showError(mess);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 10.w),
                Text("Passwords Do not match"),
              ],
            ),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 10.w),
              Text("Invalid Email"),
            ],
          ),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
        ),
      );
    }
  }

  void showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white),
            SizedBox(width: 10.w),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade400,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xff6a11cb).withOpacity(0.05),
              Color(0xff2575fc).withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(20.0).r,
          child: SingleChildScrollView(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(height: 60.h),
                    // Logo/Icon Container with Gradient
                    Container(
                      height: 120.h,
                      width: 120.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
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
                      child: Padding(
                        padding: EdgeInsets.all(15.r),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/raxxy_icon1.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 30.h),
                    // Title with Gradient
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xff6a11cb), Color(0xff2575fc)],
                      ).createShader(bounds),
                      child: Text(
                        'Create Account',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 32.sp,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      'Sign up to get started',
                      style: TextStyle(
                        fontWeight: FontWeight.w400,
                        fontSize: 16.sp,
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: 35.h),

                    // Name Field
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(6.0, 0.0, 2.0, 8.0).r,
                        child: Row(
                          children: [
                            Icon(
                              Icons.person_outline,
                              size: 18.r,
                              color: Color(0xffb2b0ff),
                            ),
                            SizedBox(width: 6.w),
                            Text(
                              'Name',
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w600,
                                color: Color(0xff6a11cb),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    buildTextField(
                      context,
                      nameController,
                      'Enter your name',
                          () => setState(() {}),
                    ),
                    SizedBox(height: 16.h),

                    // Email Field
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(6.0, 0.0, 2.0, 8.0).r,
                        child: Row(
                          children: [
                            Icon(
                              Icons.email_outlined,
                              size: 18.r,
                              color: Color(0xffb2b0ff),
                            ),
                            SizedBox(width: 6.w),
                            Text(
                              'Email',
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w600,
                                color: Color(0xff6a11cb),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    buildTextField(
                      context,
                      emailController,
                      'someone@example.com',
                          () => setState(() {}),
                    ),
                    SizedBox(height: 16.h),

                    // Password Field
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(6.0, 0.0, 2.0, 8.0).r,
                        child: Row(
                          children: [
                            Icon(
                              Icons.lock_outline,
                              size: 18.r,
                              color: Color(0xffb2b0ff),
                            ),
                            SizedBox(width: 6.w),
                            Text(
                              'Password',
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w600,
                                color: Color(0xff6a11cb),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    buildTextField(
                      context,
                      passwordController,
                      'Create a password',
                          () => setState(() {
                        pashid = !pashid;
                      }),
                      obscure: pashid,
                      pass: true,
                    ),
                    SizedBox(height: 16.h),

                    // Confirm Password Field
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(6.0, 0.0, 2.0, 8.0).r,
                        child: Row(
                          children: [
                            Icon(
                              Icons.lock_clock_outlined,
                              size: 18.r,
                              color: Color(0xffb2b0ff),
                            ),
                            SizedBox(width: 6.w),
                            Text(
                              'Confirm Password',
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w600,
                                color: Color(0xff6a11cb),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    buildTextField(
                      context,
                      confirmpasswordController,
                      'Re-enter password',
                          () => setState(() {
                        cpashid = !cpashid;
                      }),
                      obscure: cpashid,
                      pass: true,
                    ),
                    SizedBox(height: 30.h),

                    // Sign Up Button with Loading State
                    isLoading
                        ? Container(
                      height: 50.h,
                      width: 260.w,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20.r),
                        gradient: const LinearGradient(
                          colors: [Color(0xff6a11cb), Color(0xff2575fc)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xff2575fc).withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      ),
                    )
                        : Container(
                      height: 50.h,
                      width: 260.w,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20.r),
                        gradient: const LinearGradient(
                          colors: [Color(0xff6a11cb), Color(0xff2575fc)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xff2575fc).withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: signup,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20.r),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.how_to_reg_rounded,
                              color: Colors.white,
                              size: 24.r,
                            ),
                            SizedBox(width: 10.w),
                            Text(
                              'Sign Up',
                              style: TextStyle(
                                fontSize: 18.sp,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 20.h),

                    // Divider
                    Row(
                      children: [
                        Expanded(
                          child: Divider(
                            color: Colors.grey[400],
                            thickness: 1,
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10.w),
                          child: Text(
                            'OR',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            color: Colors.grey[400],
                            thickness: 1,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20.h),

                    // Login Button
                    Container(
                      height: 50.h,
                      width: 260.w,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20.r),
                        color: Theme.of(context).cardColor,
                        border: Border.all(
                          color: Color(0xffb2b0ff),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => const LoginScreen()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).cardColor,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20.r),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.login_rounded,
                              color: Color(0xff6a11cb),
                              size: 24.r,
                            ),
                            SizedBox(width: 10.w),
                            Text(
                              'Already have an account?',
                              style: TextStyle(
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w600,
                                color: Color(0xff6a11cb),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 20.h),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}