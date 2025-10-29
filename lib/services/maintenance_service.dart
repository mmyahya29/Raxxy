import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/provider.dart';

class MaintenanceService {
  static List<Map<String, dynamic>> getMaintenanceStatusForVehicle({
    required QueryDocumentSnapshot<Map<String, dynamic>> vehicle,
  }) {
    final reminders = <Map<String, dynamic>>[];

    // Oil Change
    double gap = vehicle["type"] == "Car" ? 5000.0 : 1000.0;
    double engineOil = (vehicle["engineOil"] as num).toDouble();
    double mileage = (vehicle["mileage"] as num).toDouble();

    double nextDue = engineOil + gap;
    double remaining = nextDue - mileage;

    if (remaining < 100) {
      double dis = nextDue - remaining;
      reminders.add({
        "vehicleId": vehicle.id,
        "name": "${vehicle['make']} ${vehicle['model']}",
        "title": "Oil Change",
        "dueAt": nextDue,
        "remaining": remaining,
        "distance": dis,
      });
    }

    // Tyres check
    gap = vehicle["type"] == "Car" ? 40000.0 : 10000.0;
    double tyresAge = (vehicle["tyresAge"] as num).toDouble();

    nextDue = tyresAge + gap;
    remaining = nextDue - mileage;

    if (remaining < 100) {
      double dis = nextDue - remaining;
      reminders.add({
        "vehicleId": vehicle.id,
        "name": "${vehicle['make']} ${vehicle['model']}",
        "title": "Tyres Check",
        "dueAt": nextDue,
        "remaining": remaining,
        "distance": dis,
      });
    }

    // Brakes check
    gap = vehicle["type"] == "Car" ? 10000.0 : 5000.0;
    double brakesAge = (vehicle["brakesAge"] as num).toDouble();

    nextDue = brakesAge + gap;
    remaining = nextDue - mileage;

    if (remaining < 100) {
      double dis = nextDue - remaining;
      reminders.add({
        "vehicleId": vehicle.id,
        "name": "${vehicle['make']} ${vehicle['model']}",
        "title": "Brakes Check",
        "dueAt": nextDue,
        "remaining": remaining,
        "distance": dis,
      });
    }

    return reminders;
  }

  Future<void> updateMaintenaceState(
    String id,
    WidgetRef ref,
    double distance,
    String title,
  ) async {
    final auth = ref.read(firebaseAuthProvider);
    final firestore = FirebaseFirestore.instance;

    if (title == "Oil Change") {
      final docRef = firestore
          .collection('users')
          .doc(auth.currentUser!.uid)
          .collection('vehicles')
          .doc(id);
      await docRef.update({'engineOil': distance});
    } else if (title == "Tyres Check") {
      final docRef = firestore
          .collection('users')
          .doc(auth.currentUser!.uid)
          .collection('vehicles')
          .doc(id);
      await docRef.update({'tyresAge': distance});
    } else if (title == "Brakes Check") {
      final docRef = firestore
          .collection('users')
          .doc(auth.currentUser!.uid)
          .collection('vehicles')
          .doc(id);
      await docRef.update({'brakesAge': distance});
    }
  }
}
