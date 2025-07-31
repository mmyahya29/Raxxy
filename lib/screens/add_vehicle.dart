import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../providers/provider.dart';
import '../widgets/reusable_widgets.dart';

class AddVehicleScreen extends ConsumerStatefulWidget {
  const AddVehicleScreen({super.key});

  @override
  ConsumerState<AddVehicleScreen> createState() => _AddVehicleScreenState();
}

class _AddVehicleScreenState extends ConsumerState<AddVehicleScreen> {
  String? selectedType;
  final makeController = TextEditingController();
  final modelController = TextEditingController();
  final yearController = TextEditingController();
  final mileageController = TextEditingController();

  Future<void> addVehicleForUser({
    required WidgetRef ref,
    required String type,
    required String make,
    required String model,
    required int year,
    required int mileage,
  }) async {
    final auth = ref.read(firebaseAuthProvider);
    final firestore = ref.read(firestoreProvider);

    final currentUser = auth.currentUser;
    if (currentUser == null) throw Exception("User not logged in");

    await firestore
        .collection('users')
        .doc(currentUser.uid)
        .collection('vehicles')
        .add({
      'type': type,
      'make': make,
      'model': model,
      'year': year,
      'mileage': mileage,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> saveVehicle() async {
    if (selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select vehicle type')),
      );
      return;
    }

    try {
      await addVehicleForUser(
        ref: ref,
        type: selectedType!,
        make: makeController.text.trim(),
        model: modelController.text.trim(),
        year: int.parse(yearController.text.trim()),
        mileage: int.parse(mileageController.text.trim()),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vehicle added successfully!')),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Add Vehicle')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            buildDropdown('Type', ['Car', 'Bike'], selectedType),
            SizedBox(height: 10.h),
            buildTextField(makeController, 'Make'),
            SizedBox(height: 10.h),
            buildTextField(modelController, 'Model'),
            SizedBox(height: 10.h),
            buildTextField(yearController, 'Year', inputType: TextInputType.number),
            SizedBox(height: 10.h),
            buildTextField(mileageController, 'Current Mileage', inputType: TextInputType.number),
            SizedBox(height: 20.h),
            buildSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget buildDropdown(String hint, List item, String? seltype) {
    return SizedBox(
      height: 60.h,
      width: 320.w,
      child: DropdownButtonFormField<String>(
        value: seltype,
        items: item.map((type) {
          return DropdownMenuItem<String>(
            value: type,
            child: Text(type),
          );
        }).toList(),
        onChanged: (value) {
          setState(() {
            selectedType = value;
          });
        },
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

  Widget buildSaveButton() {
    return Container(
      height: 50.h,
      width: MediaQuery.of(context).size.width - 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30.r),
      ),
      child: ElevatedButton(
        onPressed: saveVehicle,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xff6259ff),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Save Vehicle',
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.w400,
                color: Color(0xffffffff),
              ),
            ),
            SizedBox(width: 10.w),
            Icon(Icons.check_circle, size: 30.r, color: Color(0xffffffff)),
          ],
        ),
      ),
    );
  }
}
