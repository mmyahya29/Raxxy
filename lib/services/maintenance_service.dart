import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/provider.dart';

class MaintenanceService {
  static List<Map<String, dynamic>> getMaintenanceStatusForVehicle({
    required QueryDocumentSnapshot<Map<String, dynamic>> vehicle,
  }) {
    final reminders = <Map<String, dynamic>>[];
    final double mileage = (vehicle["mileage"] as num).toDouble();
    final String vehicleType = vehicle["type"];

    // Helper function to safely get field value with fallback
    double _getFieldValue(String fieldName, double fallback) {
      try {
        final data = vehicle.data();
        if (data.containsKey(fieldName)) {
          return (data[fieldName] as num?)?.toDouble() ?? fallback;
        }
        return fallback;
      } catch (e) {
        return fallback;
      }
    }

    // ===================== EXISTING CHECKS =====================

    // 1. Oil Change - CRITICAL
    double gap = vehicleType == "Car" ? 5000.0 : 1000.0;
    double engineOil = (vehicle["engineOil"] as num).toDouble();
    double nextDue = engineOil + gap;
    double remaining = nextDue - mileage;

    if (remaining < 500) {
      double dis = mileage;
      reminders.add({
        "vehicleId": vehicle.id,
        "name": "${vehicle['make']} ${vehicle['model']}",
        "title": "Oil Change",
        "dueAt": nextDue,
        "remaining": remaining,
        "distance": dis,
        "priority": remaining < 100 ? "Critical" : "High",
        "category": "Engine",
      });
    }

    // 2. Tyres Check - SAFETY
    gap = vehicleType == "Car" ? 40000.0 : 10000.0;
    double tyresAge = (vehicle["tyresAge"] as num).toDouble();
    nextDue = tyresAge + gap;
    remaining = nextDue - mileage;

    if (remaining < 2000) {
      double dis = mileage;
      reminders.add({
        "vehicleId": vehicle.id,
        "name": "${vehicle['make']} ${vehicle['model']}",
        "title": "Tyres Check",
        "dueAt": nextDue,
        "remaining": remaining,
        "distance": dis,
        "priority": remaining < 500 ? "Critical" : "Medium",
        "category": "Safety",
      });
    }

    // 3. Brakes Check - SAFETY
    gap = vehicleType == "Car" ? 10000.0 : 5000.0;
    double brakesAge = (vehicle["brakesAge"] as num).toDouble();
    nextDue = brakesAge + gap;
    remaining = nextDue - mileage;

    if (remaining < 1000) {
      double dis = mileage;
      reminders.add({
        "vehicleId": vehicle.id,
        "name": "${vehicle['make']} ${vehicle['model']}",
        "title": "Brakes Check",
        "dueAt": nextDue,
        "remaining": remaining,
        "distance": dis,
        "priority": remaining < 200 ? "Critical" : "High",
        "category": "Safety",
      });
    }

    // ===================== NEW RECOMMENDED CHECKS =====================

    // 4. Air Filter Replacement
    gap = vehicleType == "Car" ? 15000.0 : 8000.0;
    double airFilterAge = _getFieldValue("airFilterAge", engineOil);
    nextDue = airFilterAge + gap;
    remaining = nextDue - mileage;

    if (remaining < 1500) {
      double dis = mileage;
      reminders.add({
        "vehicleId": vehicle.id,
        "name": "${vehicle['make']} ${vehicle['model']}",
        "title": "Air Filter Replacement",
        "dueAt": nextDue,
        "remaining": remaining,
        "distance": dis,
        "priority": remaining < 500 ? "High" : "Medium",
        "category": "Engine",
        "description": "Clean air filter improves fuel efficiency and engine performance",
      });
    }

    // 5. Transmission Fluid (Cars only)
    if (vehicleType == "Car") {
      gap = 50000.0;
      double transmissionFluidAge = _getFieldValue("transmissionFluidAge", 0.0);
      nextDue = transmissionFluidAge + gap;
      remaining = nextDue - mileage;

      if (remaining < 5000) {
        double dis = mileage;
        reminders.add({
          "vehicleId": vehicle.id,
          "name": "${vehicle['make']} ${vehicle['model']}",
          "title": "Transmission Fluid Change",
          "dueAt": nextDue,
          "remaining": remaining,
          "distance": dis,
          "priority": remaining < 1000 ? "High" : "Medium",
          "category": "Transmission",
          "description": "Keeps transmission shifting smoothly and prevents costly repairs",
        });
      }
    }

    // 6. Coolant/Antifreeze Flush
    gap = vehicleType == "Car" ? 40000.0 : 20000.0;
    double coolantAge = _getFieldValue("coolantAge", 0.0);
    nextDue = coolantAge + gap;
    remaining = nextDue - mileage;

    if (remaining < 3000) {
      double dis = mileage;
      reminders.add({
        "vehicleId": vehicle.id,
        "name": "${vehicle['make']} ${vehicle['model']}",
        "title": "Coolant/Antifreeze Flush",
        "dueAt": nextDue,
        "remaining": remaining,
        "distance": dis,
        "priority": remaining < 1000 ? "High" : "Medium",
        "category": "Engine",
        "description": "Prevents engine overheating and corrosion",
      });
    }

    // 7. Spark Plugs Replacement
    gap = vehicleType == "Car" ? 30000.0 : 15000.0;
    double sparkPlugsAge = _getFieldValue("sparkPlugsAge", 0.0);
    nextDue = sparkPlugsAge + gap;
    remaining = nextDue - mileage;

    if (remaining < 3000) {
      double dis = mileage;
      reminders.add({
        "vehicleId": vehicle.id,
        "name": "${vehicle['make']} ${vehicle['model']}",
        "title": "Spark Plugs Replacement",
        "dueAt": nextDue,
        "remaining": remaining,
        "distance": dis,
        "priority": remaining < 1000 ? "Medium" : "Low",
        "category": "Engine",
        "description": "Ensures optimal engine performance and fuel economy",
      });
    }

    // 8. Battery Check
    gap = vehicleType == "Car" ? 30000.0 : 20000.0;
    double batteryAge = _getFieldValue("batteryAge", 0.0);
    nextDue = batteryAge + gap;
    remaining = nextDue - mileage;

    if (remaining < 3000) {
      double dis = mileage;
      reminders.add({
        "vehicleId": vehicle.id,
        "name": "${vehicle['make']} ${vehicle['model']}",
        "title": "Battery Check/Replacement",
        "dueAt": nextDue,
        "remaining": remaining,
        "distance": dis,
        "priority": remaining < 1000 ? "High" : "Medium",
        "category": "Electrical",
        "description": "Battery health check and terminal cleaning to avoid breakdowns",
      });
    }

    // 9. Brake Fluid Change
    gap = vehicleType == "Car" ? 20000.0 : 12000.0;
    double brakeFluidAge = _getFieldValue("brakeFluidAge", brakesAge);
    nextDue = brakeFluidAge + gap;
    remaining = nextDue - mileage;

    if (remaining < 2000) {
      double dis = mileage;
      reminders.add({
        "vehicleId": vehicle.id,
        "name": "${vehicle['make']} ${vehicle['model']}",
        "title": "Brake Fluid Change",
        "dueAt": nextDue,
        "remaining": remaining,
        "distance": dis,
        "priority": remaining < 500 ? "High" : "Medium",
        "category": "Safety",
        "description": "Maintains brake system efficiency and safety",
      });
    }

    // 10. Timing Belt/Chain (Cars only) - CRITICAL
    if (vehicleType == "Car") {
      gap = 100000.0;
      double timingBeltAge = _getFieldValue("timingBeltAge", 0.0);
      nextDue = timingBeltAge + gap;
      remaining = nextDue - mileage;

      if (remaining < 10000) {
        double dis = mileage;
        reminders.add({
          "vehicleId": vehicle.id,
          "name": "${vehicle['make']} ${vehicle['model']}",
          "title": "Timing Belt/Chain Inspection",
          "dueAt": nextDue,
          "remaining": remaining,
          "distance": dis,
          "priority": remaining < 2000 ? "Critical" : "High",
          "category": "Engine",
          "description": "CRITICAL: Failure can cause severe engine damage",
        });
      }
    }

    // 11. Chain/Sprocket Maintenance (Bikes only)
    if (vehicleType == "Bike") {
      gap = 5000.0;
      double chainAge = _getFieldValue("chainAge", 0.0);
      nextDue = chainAge + gap;
      remaining = nextDue - mileage;

      if (remaining < 1000) {
        double dis = mileage;
        reminders.add({
          "vehicleId": vehicle.id,
          "name": "${vehicle['make']} ${vehicle['model']}",
          "title": "Chain Lubrication/Adjustment",
          "dueAt": nextDue,
          "remaining": remaining,
          "distance": dis,
          "priority": remaining < 200 ? "High" : "Medium",
          "category": "Drivetrain",
          "description": "Essential for smooth power delivery and bike longevity",
        });
      }
    }

    // 12. Wheel Alignment (Cars only)
    if (vehicleType == "Car") {
      gap = 20000.0;
      double alignmentAge = _getFieldValue("alignmentAge", tyresAge);
      nextDue = alignmentAge + gap;
      remaining = nextDue - mileage;

      if (remaining < 2000) {
        double dis = mileage;
        reminders.add({
          "vehicleId": vehicle.id,
          "name": "${vehicle['make']} ${vehicle['model']}",
          "title": "Wheel Alignment Check",
          "dueAt": nextDue,
          "remaining": remaining,
          "distance": dis,
          "priority": remaining < 500 ? "Medium" : "Low",
          "category": "Suspension",
          "description": "Prevents uneven tire wear and improves handling",
        });
      }
    }

    // 13. Suspension Check
    gap = vehicleType == "Car" ? 30000.0 : 20000.0;
    double suspensionAge = _getFieldValue("suspensionAge", 0.0);
    nextDue = suspensionAge + gap;
    remaining = nextDue - mileage;

    if (remaining < 3000) {
      double dis = mileage;
      reminders.add({
        "vehicleId": vehicle.id,
        "name": "${vehicle['make']} ${vehicle['model']}",
        "title": "Suspension Inspection",
        "dueAt": nextDue,
        "remaining": remaining,
        "distance": dis,
        "priority": remaining < 1000 ? "Medium" : "Low",
        "category": "Suspension",
        "description": "Ensures comfortable ride and proper vehicle handling",
      });
    }

    // Sort by priority (Critical > High > Medium > Low) then by remaining distance
    reminders.sort((a, b) {
      final priorityOrder = {"Critical": 0, "High": 1, "Medium": 2, "Low": 3};
      final priorityComparison =
      priorityOrder[a["priority"]]!.compareTo(priorityOrder[b["priority"]]!);
      if (priorityComparison != 0) return priorityComparison;
      return (a["remaining"] as double).compareTo(b["remaining"] as double);
    });

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

    final docRef = firestore
        .collection('users')
        .doc(auth.currentUser!.uid)
        .collection('vehicles')
        .doc(id);

    // Map maintenance titles to their corresponding fields
    final Map<String, String> maintenanceFieldMap = {
      "Oil Change": "engineOil",
      "Tyres Check": "tyresAge",
      "Brakes Check": "brakesAge",
      "Air Filter Replacement": "airFilterAge",
      "Transmission Fluid Change": "transmissionFluidAge",
      "Coolant/Antifreeze Flush": "coolantAge",
      "Spark Plugs Replacement": "sparkPlugsAge",
      "Battery Check/Replacement": "batteryAge",
      "Brake Fluid Change": "brakeFluidAge",
      "Timing Belt/Chain Inspection": "timingBeltAge",
      "Chain Lubrication/Adjustment": "chainAge",
      "Wheel Alignment Check": "alignmentAge",
      "Suspension Inspection": "suspensionAge",
    };

    final fieldName = maintenanceFieldMap[title];

    if (fieldName != null) {
      try {
        await docRef.update({fieldName: distance});
        print('✅ Updated $title maintenance record to $distance km');
      } catch (e) {
        print('❌ Error updating maintenance state: $e');
        // If the field doesn't exist, set it with merge
        await docRef.set({fieldName: distance}, SetOptions(merge: true));
        print('✅ Created new field $fieldName with value $distance km');
      }
    } else {
      print('⚠️ Unknown maintenance title: $title');
    }
  }

  // Helper method to get all maintenance intervals for informational purposes
  static Map<String, Map<String, dynamic>> getMaintenanceIntervals(String vehicleType) {
    return {
      "Oil Change": {
        "interval": vehicleType == "Car" ? 5000.0 : 1000.0,
        "category": "Engine",
        "description": "Regular oil changes keep your engine running smoothly",
        "priority": "Critical",
      },
      "Tyres Check": {
        "interval": vehicleType == "Car" ? 40000.0 : 10000.0,
        "category": "Safety",
        "description": "Tire inspection and rotation for even wear",
        "priority": "High",
      },
      "Brakes Check": {
        "interval": vehicleType == "Car" ? 10000.0 : 5000.0,
        "category": "Safety",
        "description": "Brake pad inspection and replacement",
        "priority": "Critical",
      },
      "Air Filter Replacement": {
        "interval": vehicleType == "Car" ? 15000.0 : 8000.0,
        "category": "Engine",
        "description": "Clean air filter improves fuel efficiency",
        "priority": "Medium",
      },
      if (vehicleType == "Car") "Transmission Fluid Change": {
        "interval": 50000.0,
        "category": "Transmission",
        "description": "Keeps transmission shifting smoothly",
        "priority": "High",
      },
      "Coolant/Antifreeze Flush": {
        "interval": vehicleType == "Car" ? 40000.0 : 20000.0,
        "category": "Engine",
        "description": "Prevents engine overheating",
        "priority": "High",
      },
      "Spark Plugs Replacement": {
        "interval": vehicleType == "Car" ? 30000.0 : 15000.0,
        "category": "Engine",
        "description": "Ensures optimal engine performance",
        "priority": "Medium",
      },
      "Battery Check/Replacement": {
        "interval": vehicleType == "Car" ? 30000.0 : 20000.0,
        "category": "Electrical",
        "description": "Battery health check and terminal cleaning",
        "priority": "High",
      },
      "Brake Fluid Change": {
        "interval": vehicleType == "Car" ? 20000.0 : 12000.0,
        "category": "Safety",
        "description": "Maintains brake system efficiency",
        "priority": "High",
      },
      if (vehicleType == "Car") "Timing Belt/Chain Inspection": {
        "interval": 100000.0,
        "category": "Engine",
        "description": "CRITICAL: Failure can cause severe engine damage",
        "priority": "Critical",
      },
      if (vehicleType == "Bike") "Chain Lubrication/Adjustment": {
        "interval": 5000.0,
        "category": "Drivetrain",
        "description": "Essential for bike performance",
        "priority": "High",
      },
      if (vehicleType == "Car") "Wheel Alignment Check": {
        "interval": 20000.0,
        "category": "Suspension",
        "description": "Prevents uneven tire wear",
        "priority": "Medium",
      },
      "Suspension Inspection": {
        "interval": vehicleType == "Car" ? 30000.0 : 20000.0,
        "category": "Suspension",
        "description": "Ensures comfortable ride and handling",
        "priority": "Medium",
      },
    };
  }

  // Helper method to initialize all maintenance fields for a new vehicle
  static Map<String, dynamic> getInitialMaintenanceFields(String vehicleType, double currentMileage) {
    return {
      "engineOil": currentMileage,
      "tyresAge": currentMileage,
      "brakesAge": currentMileage,
      "airFilterAge": currentMileage,
      if (vehicleType == "Car") "transmissionFluidAge": currentMileage,
      "coolantAge": currentMileage,
      "sparkPlugsAge": currentMileage,
      "batteryAge": currentMileage,
      "brakeFluidAge": currentMileage,
      if (vehicleType == "Car") "timingBeltAge": currentMileage,
      if (vehicleType == "Bike") "chainAge": currentMileage,
      if (vehicleType == "Car") "alignmentAge": currentMileage,
      "suspensionAge": currentMileage,
    };
  }
}