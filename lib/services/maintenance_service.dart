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
    var gap = vehicle["type"] == "Car" ? 5000 : 1000;
    var nextDue = vehicle["engineOil"] + gap;
    var remaining = nextDue - vehicle["mileage"];

    if(remaining<100){
      double dis=nextDue-remaining;
      reminders.add({
        "vehicleId" : vehicle.id,
        "name": "${vehicle['make']} ${vehicle['model']}",
        "title": "Oil Change",
        "dueAt": nextDue,
        "remaining": remaining,
        "distance" : dis
      });
    }

    //Tyres check
    gap = vehicle["type"] == "Car" ? 40000 : 10000;
    nextDue=vehicle["tyresAge"]+gap;
    remaining=nextDue-vehicle["mileage"];
    if(remaining<100){
      double dis=nextDue-remaining;
      reminders.add({
        "vehicleId" : vehicle.id,
        "name": "${vehicle['make']} ${vehicle['model']}",
        "title": "Tyres Check",
        "dueAt": nextDue,
        "remaining": remaining,
        "distance" : dis
      });
    }

    //Brakes check
    gap = vehicle["type"] == "Car" ? 10000 : 5000;
    nextDue=vehicle["brakesAge"]+gap;
    remaining=nextDue-vehicle["mileage"];
    if(remaining<100){
      double dis=nextDue-remaining;
      reminders.add({
        "vehicleId" : vehicle.id,
        "name": "${vehicle['make']} ${vehicle['model']}",
        "title": "Brakes Check",
        "dueAt": nextDue,
        "remaining": remaining,
        "distance" : dis
      });
    }

    return reminders;
  }

  Future<void> updateMaintenaceState(String id, WidgetRef ref, double distance, String title) async {
    final auth = ref.read(firebaseAuthProvider);
    final firestore = FirebaseFirestore.instance;

    if(title=="Oil Change"){
      final docRef = firestore.collection('users').doc(auth.currentUser!.uid).collection('vehicles').doc(id);
      await docRef.update({'engineOil': distance});
    }else if(title=="Tyres Check"){
      final docRef = firestore.collection('users').doc(auth.currentUser!.uid).collection('vehicles').doc(id);
      await docRef.update({'tyresAge': distance});
    }else if(title=="Brakes Check"){
      final docRef = firestore.collection('users').doc(auth.currentUser!.uid).collection('vehicles').doc(id);
      await docRef.update({'brakesAge': distance});
    }
  }
}

