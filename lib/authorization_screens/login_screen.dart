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

  bool pashid=true;
  bool isLoading = false;

  final auth = FirebaseAuth.instance;
  final firestore = FirebaseFirestore.instance;


  Future<void> authenticate() async {
    final auth = ref.read(firebaseAuthProvider);
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if(emailValidator(email)){
    try {
      setState(() {
        isLoading = true;
      });
      await auth.signInWithEmailAndPassword(email: email, password: password);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Login Successful"),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        isLoading = false;
      });
      String? mess = getErrorMessage(e.code);
      showError(mess);
    }
  }
    else{
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Invalid Email"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
    }

  void showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }
  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: buildAuth(),
    );
  }

  Widget buildAuth() {

    return SingleChildScrollView(
      child: Padding(
        padding:  EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: 100.h),
            Text(
              'Login',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 26.sp),
            ),
            SizedBox(height: 40.h),
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6.0, 0.0, 2.0, 8.0).r,
                child: Text(
                  'Email',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            buildTextField(context, emailController, 'someone@example.com', () => setState(() {})),
            SizedBox(height: 20.h),
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6.0, 0.0, 2.0, 8.0).r,
                child: Text(
                  'Password',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            buildTextField(context, passwordController, 'Password', () => setState(() {pashid=!pashid; print(pashid);}), obscure: pashid, pass: true),
            SizedBox(height: 20.h),
            isLoading? Container(
              height: 50.h,
              width: 260.w,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20.r),
                color: const Color(0xff664bff),
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                ),
              ),
            ):
            buildButton('Login', authenticate, null),
            SizedBox(height: 10.h),
            TextButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const SignupScreen()),
                );
              },
              child: Text('No account? Sign Up', style: TextStyle(color: Colors.blueAccent)),
            ),
            TextButton(
              onPressed: (){
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => ResetPasswordScreen()),
                );
              },
              child: const Text('Forgot Password?',style: TextStyle(color: Colors.blueAccent)),
            ),
            SizedBox(height: 20.h),
          ],
        ),
      ),
    );
  }
}
