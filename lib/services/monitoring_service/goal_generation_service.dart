import 'package:cloud_firestore/cloud_firestore.dart';

class GoalsGenerationService {
  /// Generate or update goals based on session performance
  static Future<void> generateGoals({
    required String userId,
    required String vehicleId,
    required int harshAccelEvents,
    required int harshBrakeEvents,
    required int sessionDurationMinutes,
  }) async {
    if (sessionDurationMinutes == 0) {
      print('⚠️ Session duration is 0, skipping goal generation');
      return;
    }

    final firestore = FirebaseFirestore.instance;
    final goalsCollection = firestore
        .collection('users')
        .doc(userId)
        .collection('goals');

    try {
      // Get current goals
      final currentGoalsSnapshot = await goalsCollection.get();
      final currentGoals = currentGoalsSnapshot.docs
          .map((doc) => {...doc.data(), 'id': doc.id})
          .toList();

      // Calculate events per minute
      double accEventsPerMinute = harshAccelEvents / sessionDurationMinutes;
      double brEventsPerMinute = harshBrakeEvents / sessionDurationMinutes;

      print('🎯 Goal Generation Analysis:');
      print('   Accel events/min: ${accEventsPerMinute.toStringAsFixed(2)}');
      print('   Brake events/min: ${brEventsPerMinute.toStringAsFixed(2)}');

      // Delete completed goals
      await _deleteCompletedGoals(
        firestore: firestore,
        userId: userId,
        currentGoals: currentGoals,
        accEventsPerMinute: accEventsPerMinute,
        brEventsPerMinute: brEventsPerMinute,
      );

      // Add new goals if needed
      await _addNewGoals(
        firestore: firestore,
        userId: userId,
        vehicleId: vehicleId,
        currentGoals: currentGoals,
        accEventsPerMinute: accEventsPerMinute,
        brEventsPerMinute: brEventsPerMinute,
        sessionDurationMinutes: sessionDurationMinutes,
      );
    } catch (e) {
      print('❌ Failed to generate goals: $e');
      rethrow;
    }
  }

  /// Delete goals that have been completed
  static Future<void> _deleteCompletedGoals({
    required FirebaseFirestore firestore,
    required String userId,
    required List<Map<String, dynamic>> currentGoals,
    required double accEventsPerMinute,
    required double brEventsPerMinute,
  }) async {
    const double completionThreshold = 0.2; // events per minute

    for (var goal in currentGoals) {
      bool shouldDelete = false;

      if (goal["title"] == "Improve Smooth Throttle" &&
          accEventsPerMinute < completionThreshold) {
        shouldDelete = true;
      } else if (goal["title"] == "Improve Smooth Braking" &&
          brEventsPerMinute < completionThreshold) {
        shouldDelete = true;
      }

      if (shouldDelete) {
        await firestore
            .collection('users')
            .doc(userId)
            .collection('goals')
            .doc(goal["id"])
            .delete();

        print('✅ Goal completed and deleted: ${goal['title']}');
      }
    }
  }

  /// Add new goals if performance needs improvement
  static Future<void> _addNewGoals({
    required FirebaseFirestore firestore,
    required String userId,
    required String vehicleId,
    required List<Map<String, dynamic>> currentGoals,
    required double accEventsPerMinute,
    required double brEventsPerMinute,
    required int sessionDurationMinutes,
  }) async {
    const double improvementThreshold = 0.2; // events per minute

    // Add acceleration goal if needed
    if (accEventsPerMinute > improvementThreshold) {
      final goal = {
        "vehicleId": vehicleId,
        "title": "Improve Smooth Throttle",
        "description": "Reduce harsh acceleration in your next trips.",
        "createdAt": FieldValue.serverTimestamp(),
        "target":
        "Drive with fewer than ${(sessionDurationMinutes * improvementThreshold).toStringAsFixed(0)} harsh events",
      };

      if (!_goalExists(currentGoals, goal)) {
        await firestore
            .collection("users")
            .doc(userId)
            .collection("goals")
            .add(goal);
        print('🎯 New goal generated: ${goal['title']}');
      }
    }

    // Add braking goal if needed
    if (brEventsPerMinute > improvementThreshold) {
      final goal = {
        "vehicleId": vehicleId,
        "title": "Improve Smooth Braking",
        "description": "Reduce harsh braking in your next trips.",
        "createdAt": FieldValue.serverTimestamp(),
        "target":
        "Drive with fewer than ${(sessionDurationMinutes * improvementThreshold).toStringAsFixed(0)} harsh events",
      };

      if (!_goalExists(currentGoals, goal)) {
        await firestore
            .collection("users")
            .doc(userId)
            .collection("goals")
            .add(goal);
        print('🎯 New goal generated: ${goal['title']}');
      }
    }
  }

  /// Check if a goal already exists
  static bool _goalExists(
      List<Map<String, dynamic>> goals,
      Map<String, dynamic> newGoal,
      ) {
    return goals.any(
          (goal) =>
      goal["title"] == newGoal["title"] &&
          goal["vehicleId"] == newGoal["vehicleId"],
    );
  }

  /// Delete all goals for a specific vehicle
  static Future<void> deleteGoalsForVehicle({
    required String userId,
    required String vehicleId,
  }) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final goalsSnapshot = await firestore
          .collection('users')
          .doc(userId)
          .collection('goals')
          .where('vehicleId', isEqualTo: vehicleId)
          .get();

      for (var doc in goalsSnapshot.docs) {
        await doc.reference.delete();
      }

      print('✅ Deleted all goals for vehicle $vehicleId');
    } catch (e) {
      print('❌ Failed to delete goals for vehicle: $e');
      rethrow;
    }
  }
}