import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:persistent_bottom_nav_bar/persistent_bottom_nav_bar.dart';
import 'package:raxxy/screens/settings_subscreens/user_management.dart';
import '../providers/provider.dart';
import '../providers/safety_feature_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/reusable_widgets.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  final PersistentTabController controller;
  const SettingsScreen({super.key, required this.controller});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {

  final emNumController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final auth = ref.read(firebaseAuthProvider);
    final username = auth.currentUser?.displayName ?? 'No Name';
    final themeMode = ref.watch(themeNotifierProvider);
    final crash = ref.watch(featureNotifierProvider);

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
              InkWell(
                onTap: (){
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ProfileManagement()),
                  );
                },
                child: Container(
                  height: 80.h,
                  width: MediaQuery.of(context).size.width-40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30.r),
                    color: Theme.of(context).cardColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 4,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_rounded, size: 80.r, color: Color(0xffb2b0ff),),
                      SizedBox(width: 5.w,),
                      Text(username, style: TextStyle(fontSize: 26.sp, fontWeight: FontWeight.w600),),
                      SizedBox(width: 60.w,)
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20.h,),
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
                  onPressed: () {
                    ref.read(themeNotifierProvider.notifier).toggleTheme();
                  },
                  child: Text(themeMode == ThemeMode.dark
                      ? "Switch to Light Mode"
                      : "Switch to Dark Mode",
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w700,
                    ),),
                ),
              ),

              SizedBox(height: 10.h,),
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOut,
                child: Column(
                  children: [
                    SizedBox(height: 10.h),
                    Container(
                      height: 50.h,
                      width: MediaQuery.of(context).size.width - 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20.r),
                        color: Color(0xff202020),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 4,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          ref.read(featureNotifierProvider.notifier).togglefeature();
                        },
                        child: Text(
                          'Crash Detection: ${(crash == false) ? 'Disabled' : 'Enabled'}',
                          style: TextStyle(
                            fontSize: 20.sp,
                            fontWeight: FontWeight.w700,
                            color: Color(0xffffffff),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 10.h),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      child: crash ? Column(
                        children: [
                          buildTextField(
                            context,
                            emNumController,
                            "Phone Number",
                                () => setState(() {}),
                          ),
                          SizedBox(height: 10.h),
                          buildButton("save", ()=>{saveEmergency(), Navigator.pop(context)}, null),
                        ],
                      ): const SizedBox.shrink(),
                    )
                  ],
                ),
              ),
              SizedBox(height:10.h),
              Container(
                height: 50.h,
                width: MediaQuery.of(context).size.width - 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20.r),
                  color: Color(0xff202020),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 4,
                      spreadRadius: 3,
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: () async {
                    await auth.signOut();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xffb10000),
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
                          color: Color(0xffffffff),
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Icon(Icons.logout_rounded, size: 30.r, color: Color(
                          0xffffffff)),
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

  Future<void> saveEmergency() async {
    final auth = ref.read(firebaseAuthProvider);
    final firestore = FirebaseFirestore.instance;
    final userDoc = firestore.collection('users').doc(auth.currentUser!.uid);
    //final snapshot = await userDoc.get();
    // double currentScore = (snapshot.data()?['emergencyContact'] ?? 50).toDouble();
    try {
      await userDoc.set({
        'emergencyContact': emNumController.text.trim(),
      }, SetOptions(merge: true));

    } catch (e) {
      print(e);
    }
  }
}
