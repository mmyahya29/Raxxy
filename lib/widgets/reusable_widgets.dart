import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

Widget buildTextField(BuildContext context, TextEditingController controller, String hint, VoidCallback rebuild, {bool pass=false, bool obscure = false, TextInputType inputType = TextInputType.text}) {

  return Container(
    height: 50.h,
    width: 320.w,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20.r),
      color: Theme.of(context).cardColor,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.3),
          blurRadius: 4,
          spreadRadius: 3,
        ),
      ],
    ),
    child: TextFormField(
      controller: controller,
      keyboardType: inputType,
      obscureText: obscure,
      decoration: InputDecoration(
        filled: true,
        hintText: hint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20.r),
          borderSide: BorderSide.none,
        ),
          suffixIcon: (pass==true)?IconButton(
          onPressed: () {
            rebuild();
          },
          icon: Icon(Icons.remove_red_eye_outlined),
          color: obscure?Colors.blueGrey:Color(0xff664bff),
        ):null,
      ),
    ),
  );
}

Widget buildButton(String text, VoidCallback onPressed, String? image, {Color color = const Color(0xff664bff)}) {
  return Container(
    height: 50.h,
    width: 260.w,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20.r),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.3),
          blurRadius: 4,
          spreadRadius: 3,
        ),
      ],
    ),
    child: ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            text,
            style: TextStyle(fontSize: 18.sp, color: Colors.white),
          ),
          if(image!=null)
          SizedBox(
            height: 40.h,
            width: 40.w,
            child: Image.asset(image),
          ),
        ],
      ),
    ),
  );
}
bool emailValidator(String? value) {
  if (value == null || value.isEmpty) {
    return false;
  }

  // Simple regex for basic email format validation
  final regex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');

  return regex.hasMatch(value);
}

String getErrorMessage(String errorCode) {
  switch (errorCode) {
    case 'user-not-found':
      return 'No account found with this email';
    case 'wrong-password':
      return 'Incorrect password. Please try again';
    case 'invalid-email':
      return 'Please enter a valid email address';
    case 'user-disabled':
      return 'This account has been disabled';
    case 'too-many-requests':
      return 'Too many failed attempts. Please try again later';
    case 'network-request-failed':
      return 'Network error. Check your connection';
    case 'invalid-credential':
      return 'Invalid email or password. Please try again';
    default:
      return 'An error occurred. Please try again';
  }
}
