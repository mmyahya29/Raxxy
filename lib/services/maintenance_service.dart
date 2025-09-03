import 'package:cloud_firestore/cloud_firestore.dart';
import 'maintenance_rules.dart';
import 'maintenance_status.dart';

class MaintenanceService {
  static List<Map<String, dynamic>> getMaintenanceStatusForVehicle({
    required String vehicleName,
    required String type, // "car" or "bike"
    required double lastOilChange,
    required double currentMileage,
  }) {
    final reminders = <Map<String, dynamic>>[];

    // Oil Change
    final oilGap = type == "car" ? 5000 : 1000;
    final nextDue = lastOilChange + oilGap;
    final remaining = nextDue - currentMileage;

    if(remaining<100){
      reminders.add({
        "name": vehicleName,
        "title": "Oil Change",
        "dueAt": nextDue,
        "remaining": remaining,
      });
    }

    // TODO: Add Tire, Brake, Air Filter here...

    return reminders;
  }
}

