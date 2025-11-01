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
  void initState() {
    super.initState();
    _syncEmergencyContact();
  }

  Future<void> _syncEmergencyContact() async {
    // Listen to the emContactProvider once to get the value
    final prefs = ref.read(sharedPreferencesProvider);
    String? emergencyContact = prefs.getString('emergency_contact');
    emNumController.text = emergencyContact!;
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.read(firebaseAuthProvider);
    final username = auth.currentUser?.displayName ?? 'No Name';
    final themeMode = ref.watch(themeNotifierProvider);
    final crash = ref.watch(featureNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0).r,

          child: Column(
            children: [
              SizedBox(height: 10.h),
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ProfileManagement()),
                  );
                },
                child: Container(
                  height: 80.h,
                  width: MediaQuery.of(context).size.width - 40,
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
                      Icon(
                        Icons.person_rounded,
                        size: 80.r,
                        color: Color(0xffb2b0ff),
                      ),
                      SizedBox(width: 5.w),
                      Text(
                        username,
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                          fontSize: 26.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 60.w),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20.h),
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
                  child: Text(
                    themeMode == ThemeMode.dark
                        ? "Switch to Light Mode"
                        : "Switch to Dark Mode",
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

              SizedBox(height: 10.h),
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
                          ref
                              .read(featureNotifierProvider.notifier)
                              .togglefeature();
                          if (crash == true) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Crash Detection Disabled"),
                                backgroundColor: Colors.red.shade600,
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(seconds: 3),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Crash Detection Enabled"),
                                backgroundColor: Colors.green.shade600,
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(seconds: 3),
                              ),
                            );
                          }
                        },
                        child: Text(
                          'Crash Detection: ${(crash == false) ? 'Disabled' : 'Enabled'}',
                          style: TextStyle(
                            fontSize: 20.sp,
                            fontWeight: FontWeight.w700,
                            color:
                                Theme.of(context).textTheme.bodyMedium?.color,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 10.h),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      child:
                          crash
                              ? Column(
                                children: [
                                  buildTextField(
                                    context,
                                    emNumController,
                                    "Phone Number",
                                    () => setState(() {}),
                                  ),
                                  SizedBox(height: 10.h),
                                  buildButton("save", saveEmergency, null),
                                ],
                              )
                              : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
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
                  onPressed: () async {
                    showDialog(
                      context: context,
                      builder:
                          (ctx) => AlertDialog(
                            title: const Text("Logging Out?"),
                            content: Text("Are you sure you want to Logout?"),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(false),
                                child: const Text("Cancel"),
                              ),
                              ElevatedButton(
                                onPressed: () async {
                                  await auth.signOut();
                                  Navigator.of(ctx).pop(true);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                ),
                                child: const Text(
                                  "Logout",
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8A2E3B),
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
                      Icon(
                        Icons.logout_rounded,
                        size: 30.r,
                        color: Color(0xffffffff),
                      ),
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

  bool phoneValidator(String? value) {
    if (value == null || value.isEmpty) {
      return false;
    }

    // Regex for +92 followed by 10 digits
    final regex = RegExp(r'^\+92\d{10}$');

    if (!regex.hasMatch(value)) {
      return false;
    }

    return true; // valid
  }

  Future<void> saveEmergency() async {
    final auth = ref.read(firebaseAuthProvider);
    final firestore = FirebaseFirestore.instance;
    final userDoc = firestore.collection('users').doc(auth.currentUser!.uid);
    final prefs = ref.read(sharedPreferencesProvider);

    final phone = emNumController.text.trim();

    if (phoneValidator(phone)) {
      try {
        await userDoc.set({'emergencyContact': phone}, SetOptions(merge: true));

        await prefs.setString('emergency_contact', phone);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("✅ Emergency contact saved successfully!"),
              backgroundColor: Colors.green.shade600,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        }

        print("$phone added to database");
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("❌ Failed to save contact. Please try again."),
              backgroundColor: Colors.red.shade600,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        print(e);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              "⚠️ Enter a valid number in +92XXXXXXXXXX format",
            ),
            backgroundColor: Colors.orange.shade700,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      print("Enter a Valid number in +92XXXXXXXXXX");
    }
  }

  Future<String> getEmergency() async {
    final auth = ref.read(firebaseAuthProvider);
    final firestore = FirebaseFirestore.instance;
    final userDoc = firestore.collection('users').doc(auth.currentUser!.uid);
    final snapshot = await userDoc.get();
    String contact = snapshot.data()?['emergencyContact'];
    return contact;
  }
}
