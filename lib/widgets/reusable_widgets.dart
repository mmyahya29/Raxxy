import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Shows a custom floating [SnackBar] that clears the persistent bottom
/// navigation bar. Pass [icon] and set [terminalStyle] to `true` to enable
/// the HUD-style terminal look used on auth screens.
void showAppSnackBar(
  BuildContext context,
  String message, {
  Color backgroundColor = Colors.black,
  Duration duration = const Duration(seconds: 3),
  IconData? icon,
  bool terminalStyle = false,
}) {
  final Widget content = (terminalStyle || icon != null)
      ? Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white, size: 20.r),
              SizedBox(width: 10.w),
            ],
            Expanded(
              child: Text(
                terminalStyle ? message.toUpperCase() : message,
                style: terminalStyle
                    ? TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12.sp,
                        letterSpacing: 1,
                      )
                    : const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        )
      : Text(message, style: const TextStyle(fontWeight: FontWeight.bold));

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: content,
      backgroundColor: backgroundColor.withOpacity(0.95),
      behavior: SnackBarBehavior.floating,
      duration: duration,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
      ),
      // Bottom margin is large enough to clear the persistent floating nav bar.
      margin: EdgeInsets.fromLTRB(16.w, 0, 16.w, 90.h),
    ),
  );
}

Widget buildTextField(
    BuildContext context,
    TextEditingController controller,
    String hint,
    VoidCallback rebuild, {
      bool pass = false,
      bool obscure = false,
      TextInputType inputType = TextInputType.text,
    }) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final accentColor = const Color(0xFF00E5FF); // RAXXY Cyan

  return TextFormField(
    controller: controller,
    keyboardType: inputType,
    obscureText: obscure,
    style: TextStyle(
      color: isDark ? Colors.white : Colors.black87,
      fontWeight: FontWeight.w700,
      fontSize: 14.sp,
      letterSpacing: obscure ? 3.0 : 0.5, // Spreads out password dots
    ),
    decoration: InputDecoration(
      filled: true,
      fillColor: isDark ? const Color(0xFF0A0E27) : Colors.grey.shade100,
      hintText: hint,
      hintStyle: TextStyle(
        color: isDark ? Colors.white30 : Colors.black26,
        fontWeight: FontWeight.w500,
        fontSize: 13.sp,
        letterSpacing: 0.5,
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 18.h),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.r),
        borderSide: BorderSide(
          color: isDark ? Colors.white10 : Colors.black12,
          width: 1.5,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.r),
        borderSide: BorderSide(color: accentColor, width: 2),
      ),
      suffixIcon: pass
          ? IconButton(
        onPressed: rebuild,
        icon: Icon(
          obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
          size: 20.r,
        ),
        color: obscure
            ? (isDark ? Colors.white30 : Colors.black26)
            : accentColor,
      )
          : null,
    ),
  );
}

Widget buildButton(String text, VoidCallback onPressed, String? image, {Color color = const Color(0xFF8B7CFF)}) {
  return Container(
      height: 55.h,
      width: 260.w,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent, // Color is handled by the Ink container
          shadowColor: Colors.transparent,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
        ),
        child: Ink(
          decoration: BoxDecoration(
            color: color.withOpacity(0.1), // Base color
            gradient: LinearGradient(
              colors: [color, color.withBlue(255)], // Subtle gradient pop
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
          ),
          child: Container(
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  text.toUpperCase(),
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 1.5,
                  ),
                ),
                if (image != null) ...[
                  SizedBox(width: 10.w),
                  SizedBox(
                    height: 24.r,
                    width: 24.r,
                    child: Image.asset(image, color: Colors.white),
                  ),
                ],
              ],
            ),
          ),
        ),
      ));
  }


bool emailValidator(String? value) {
  if (value == null || value.isEmpty) {
    return false;
  }
  // Standard regex for basic email format validation
  final regex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
  return regex.hasMatch(value);
}

String getErrorMessage(String errorCode) {
  switch (errorCode) {
    case 'user-not-found':
      return 'CREDENTIAL NOT FOUND: Pilot designation unregistered.';
    case 'wrong-password':
      return 'ENCRYPTION MISMATCH: Invalid passphrase.';
    case 'invalid-email':
      return 'INVALID PROTOCOL: Corrupted email format.';
    case 'user-disabled':
      return 'ACCESS DENIED: Pilot account suspended by network admin.';
    case 'too-many-requests':
      return 'NETWORK LOCKDOWN: Excessive failed attempts. Standby.';
    case 'network-request-failed':
      return 'UPLINK FAILED: Check local network connection.';
    case 'invalid-credential':
      return 'AUTHENTICATION FAILED: Invalid credentials provided.';
    default:
      return 'SYSTEM ERROR: Operation aborted. Please retry.';
  }
}