import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:raxxy/authorization_screens/resetpassword_screen.dart';
import 'package:raxxy/authorization_screens/signup_screen.dart';
import 'package:raxxy/providers/provider.dart';

import '../widgets/reusable_widgets.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  final auth = FirebaseAuth.instance;
  final firestore = FirebaseFirestore.instance;

  Future<void> authenticate() async {
    final auth = ref.read(firebaseAuthProvider);
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    try {
      await auth.signInWithEmailAndPassword(email: email, password: password);
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
            SizedBox(height: 10.h),
            buildTextField(context, passwordController, 'Password', obscure: true),
            SizedBox(height: 20.h),
            buildButton('Login', authenticate, null),
            SizedBox(height: 10.h),
            TextButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const SignupScreen()),
                );
              },
              child: Text('No account? Sign Up'),
            ),
            TextButton(
              onPressed: (){
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => ResetPasswordScreen()),
                );
              },
              child: const Text('Forgot Password?'),
            ),
            SizedBox(height: 20.h),
          ],
        ),
      ),
    );
  }
}
