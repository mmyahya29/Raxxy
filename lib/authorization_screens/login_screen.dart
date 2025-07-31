import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:raxxy/providers/provider.dart';
import '../widgets/reusable_widgets.dart';
import 'signup_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  Future<void> login() async {
    final auth = ref.read(firebaseAuthProvider);
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    try {
      await auth.signInWithEmailAndPassword(email: email, password: password);
    } catch (e) {
      showError(e.toString());
    }
  }

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
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(height: 100.h),
              Text('Login', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 26.sp)),
              SizedBox(height: 40.h),
              buildTextField(emailController, 'Email'),
              SizedBox(height: 10.h),
              buildTextField(passwordController, 'Password', obscure: true),
              SizedBox(height: 20.h),
              buildButton('Login', login, null),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SignupScreen()),
                  );
                },
                child: const Text('No account? Sign Up'),
              ),
              TextButton(
                onPressed: resetPassword,
                child: const Text('Forgot Password?'),
              ),
              SizedBox(height: 20.h),
            ],
          ),
        ),
      ),
    );
  }
}
