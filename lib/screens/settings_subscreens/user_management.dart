import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:persistent_bottom_nav_bar/persistent_bottom_nav_bar.dart';

import '../../providers/provider.dart';


class ProfileManagement extends ConsumerStatefulWidget {
  const ProfileManagement({super.key});

  @override
  ConsumerState<ProfileManagement> createState() => _ProfileManagementState();
}

class _ProfileManagementState extends ConsumerState<ProfileManagement> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile Management'),
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 0).r,
        child: SingleChildScrollView(
          child: Column(
            children: [
              SizedBox(height: 20.h,),
              // Container(
              //   height: 100.h,
              //   width: 110.w,
              //   decoration: BoxDecoration(
              //     borderRadius: BorderRadius.circular(100.r),
              //     color: Theme.of(context).cardColor,
              //     boxShadow: [
              //       BoxShadow(
              //         color: Colors.black.withOpacity(0.3),
              //         blurRadius: 4,
              //         spreadRadius: 3,
              //       ),
              //     ],
              //   ),
              //   child: Icon(Icons.camera_alt, size: 80.r,color: Color(0xffb2b0ff),),
              // ),
              // SizedBox(height: 20.h,),
              Container(
                height: 50.h,
                width: MediaQuery.of(context).size.width - 40,
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
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).cardColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20.r),
                    ),

                  ),
                  onPressed: (){
                    _showChangeNameDialog(context, ref);
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.title, color: Color(0xffb2b0ff), size: 40.r,),
                      Text("  Change Name",
                        style: TextStyle(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.w700,
                        ),),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 10.h,),
              Container(
                height: 50.h,
                width: MediaQuery.of(context).size.width - 40,
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
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).cardColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20.r),
                    ),

                  ),
                  onPressed: (){
                    _showChangeEmailDialog(context, ref);
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.email, color: Color(0xffb2b0ff), size: 40.r,),
                      Text("  Change Email",
                        style: TextStyle(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.w700,
                        ),),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 10.h,),
              Container(
                height: 50.h,
                width: MediaQuery.of(context).size.width - 40,
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
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).cardColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20.r),
                    ),

                  ),
                  onPressed: (){
                    _resetPassword(context, ref);
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_reset, color: Color(0xffb2b0ff), size: 40.r,),
                      Text("  Change Password",
                        style: TextStyle(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.w700,
                        ),),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),

    );
  }

  void _showChangeNameDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Change Display Name"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "Enter new name"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final auth = ref.read(firebaseAuthProvider);
              if (controller.text.trim().isNotEmpty) {
                await auth.currentUser?.updateDisplayName(controller.text.trim());
                await auth.currentUser?.reload();
                Navigator.pop(ctx);
                setState(() {}); // refresh UI
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _resetPassword(BuildContext context, WidgetRef ref) async {
    final auth = ref.read(firebaseAuthProvider);
    final email = auth.currentUser?.email;
    if (email != null) {
      await auth.sendPasswordResetEmail(email: email);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Password reset email sent to $email")),
      );
    }
  }
  void _showChangeEmailDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Change Email"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "Enter new email"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final auth = ref.read(firebaseAuthProvider);
              if (controller.text.trim().isNotEmpty) {
                try {
                  await auth.currentUser?.updateEmail(controller.text.trim());
                  await auth.currentUser?.reload();
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Email updated successfully")),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error: $e")),
                  );
                }
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

}