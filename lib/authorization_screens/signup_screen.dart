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

class _SignupScreenState extends ConsumerState<SignupScreen> {

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmpasswordController = TextEditingController();

  bool pashid=true;
  bool cpashid=true;

  bool isLoading=false;

  final firestore = FirebaseFirestore.instance;

  Future<void> signup() async {
    final auth = ref.read(firebaseAuthProvider);
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final cpassword = confirmpasswordController.text.trim();
    final password = passwordController.text.trim();

    if(emailValidator(email)){
      if(password==cpassword&&password!=""&&cpassword!=""){
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
                content: Text("✅ Account Created Successfully"),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 3),
              ),
            );
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const MyApp()),
            );
          }
        }on FirebaseAuthException catch (e) {
          setState(() {
            isLoading = false;
          });
          String? mess = getErrorMessage(e.code);
          showError(mess);
        }
      }else{
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ Passwords Do not match"),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
    else{
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❌ Invalid Email"),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }


  void showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("❌ $message"),
        backgroundColor: Colors.red.shade400,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
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
              buildTextField(context, nameController, 'Name',() => setState(() {})),
              SizedBox(height: 10.h),
              buildTextField(context, emailController, 'Email',() => setState(() {})),
              SizedBox(height: 10.h),
              buildTextField(context, passwordController, 'Password', () => setState(() {pashid=!pashid;}), obscure: pashid, pass: true),
              SizedBox(height: 10.h),
              buildTextField(context, confirmpasswordController, 'Confirm Password', () => setState(() {cpashid=!cpashid;}), obscure: cpashid, pass: true),
              SizedBox(height: 20.h),
              isLoading?Container(
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
              buildButton('Sign Up', signup, null),
              SizedBox(height: 10.h),
              TextButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const MyApp()),
                  );
                },
                child: const Text('Have an account? Login',style: TextStyle(color: Colors.blueAccent)),
              ),
              SizedBox(height: 20.h),
            ],
          ),
        ),
      ),
    );
  }
}
