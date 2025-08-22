import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:raxxy/authorization_screens/signup_screen.dart';
import 'package:raxxy/main.dart';
import 'package:raxxy/providers/provider.dart';

import '../widgets/reusable_widgets.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final emailController = TextEditingController();

  final auth = FirebaseAuth.instance;
  final firestore = FirebaseFirestore.instance;

  Future<void> resetPassword() async {
    final auth = ref.read(firebaseAuthProvider);
    final email = emailController.text.trim();

    if (email.isEmpty) {
      showError('Please enter your email to reset password');
      return;
    }

    try {
      await auth.sendPasswordResetEmail(email: email);
      showMessage('Password reset email sent.');
    } catch (e) {
      showError(e.toString());
    }
  }

  void showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $message')));
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: buildAuth(),
    );
  }

  Widget buildAuth() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: 100.h),
            Text(
              'Login',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 26.sp),
            ),
            SizedBox(height: 40.h),
            buildTextField(context, emailController, 'Email'),
            SizedBox(height: 20.h),
            buildButton('Reset', resetPassword, null),
            SizedBox(height: 10.h),
            TextButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => MyApp()),
                );
              },
              child: Text('Back to Login',style: TextStyle(color: Colors.blueAccent)),
            ),
          ],
        ),
      ),
    );
  }
}
