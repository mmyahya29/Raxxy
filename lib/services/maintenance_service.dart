import 'dart:ffi';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/provider.dart';
import 'maintenance_rules.dart';
import 'maintenance_status.dart';

class MaintenanceService {
  static List<Map<String, dynamic>> getMaintenanceStatusForVehicle({
    required QueryDocumentSnapshot<Map<String, dynamic>> vehicle,
  }) {
    final reminders = <Map<String, dynamic>>[];

    // Oil Change
    final oilGap = vehicle["type"] == "Car" ? 5000 : 1000;
    final nextDue = vehicle["engineOil"] + oilGap;
    final remaining = nextDue - vehicle["mileage"];

    if(remaining<100){
      reminders.add({
        "name": "${vehicle['make']} ${vehicle['model']}",
        "title": "Oil Change",
        "dueAt": nextDue,
        "remaining": remaining,
      });
    }

    // TODO: Add Tire, Brake, Air Filter here...

    return reminders;
  }

  Future<void> updateOilChange(QueryDocumentSnapshot<Map<String, dynamic>> vehicle, WidgetRef ref, double distance) async {
    final auth = ref.read(firebaseAuthProvider);
    final firestore = FirebaseFirestore.instance;
    final docRef = firestore.collection('users').doc(auth.currentUser!.uid).collection('vehicles').doc(vehicle.id);
    await docRef.update({'engineOil': distance});
  }
}

