import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:raxxy/providers/provider.dart';

import '../widgets/reusable_widgets.dart';
import 'login_screen.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  final firestore = FirebaseFirestore.instance;

  Future<void> signup() async {
    final auth = ref.read(firebaseAuthProvider);
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    try {
      await auth.createUserWithEmailAndPassword(email: email, password: password);
      final user = auth.currentUser;
      if (user != null) {
        await firestore.collection('users').doc(user.uid).set({
          'email': user.email,
          'name': user.displayName ?? '',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      showError(e.toString());
    }
  }

  void showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $message')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(height: 100.h),
              Text('Sign Up', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 26.sp)),
              SizedBox(height: 40.h),
              buildTextField(emailController, 'Email'),
              SizedBox(height: 10.h),
              buildTextField(passwordController, 'Password', obscure: true),
              SizedBox(height: 20.h),
              buildButton('Sign Up', signup, null),
              TextButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
                child: const Text('Have an account? Login'),
              ),
              SizedBox(height: 20.h),
            ],
          ),
        ),
      ),
    );
  }
}
