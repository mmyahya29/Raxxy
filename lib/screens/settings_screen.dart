import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../providers/provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int? expandedIndex;
  String? monitoringVehicleId; // Track which vehicle is being monitored

  @override
  Widget build(BuildContext context) {
    final auth = ref.read(firebaseAuthProvider);
    final username = auth.currentUser?.displayName ?? 'No Name';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0).r,
        child: SingleChildScrollView(
          child: Column(
            children: [
              SizedBox(height: 10.h,),
              Container(
                height: 140.h,
                width: 160.w,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(300.r),
                  color: Color(0xff7c7c7c)
                ),
                child: Center(child: Icon(Icons.person_rounded, size: 140.r, color: Color(0xffb2b0ff),),),
              ),
              SizedBox(height: 5.h,),
              Text(username, style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w600),),
              SizedBox(height: 10.h,),
              SizedBox(
                height: 50.h,
                width: MediaQuery.of(context).size.width - 40,
                child: ElevatedButton(
                  onPressed: () async {
                    await auth.signOut();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xffb2b0ff),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20.0),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Logout',
                        style: TextStyle(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.w700,
                          color: Color(0xffff0000),
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Icon(Icons.logout_rounded, size: 30.r, color: Color(0xffff0000)),
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
}
