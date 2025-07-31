import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

Widget buildTextField(TextEditingController controller, String hint, {bool obscure = false, TextInputType inputType = TextInputType.text}) {
  return SizedBox(
    height: 60.h,
    width: 320.w,
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
      ),
    ),
  );
}

Widget buildButton(String text, VoidCallback onPressed, String? image, {Color color = const Color(0xff664bff)}) {
  return Container(
    height: 50.h,
    width: 260.w,
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