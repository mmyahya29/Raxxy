import 'package:cloud_firestore/cloud_firestore.dart';

class DrivingScoreService {
  /// Update user's driving score based on session performance
  static Future<void> updateDrivingScore({
    required String userId,
    required int harshAccelEvents,
    required int harshBrakeEvents,
    required int sessionDurationMinutes,
  }) async {
    final firestore = FirebaseFirestore.instance;
    final userDoc = firestore.collection('users').doc(userId);

    if (sessionDurationMinutes == 0) {
      print('⚠️ Session duration is 0, skipping driving score update');
      return;
    }

    try {
      await firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(userDoc);

        if (!snapshot.exists) {
          print('⚠️ User document does not exist, cannot update driving score');
          return;
        }

        double currentScore = (snapshot.data()?['drivingScore'] ?? 50.0).toDouble();

        // Calculate harsh events per minute
        final harshEventsPerMinute =
            (harshAccelEvents + harshBrakeEvents) / sessionDurationMinutes;

        // Determine score adjustment based on performance
        double scoreAdjustment;
        String performance;

        if (harshEventsPerMinute <= 0.1) {
          scoreAdjustment = 1.0;
          performance = 'Excellent';
        } else if (harshEventsPerMinute <= 0.3) {
          scoreAdjustment = 0.0;
          performance = 'Good';
        } else {
          scoreAdjustment = -1.0;
          performance = 'Needs Improvement';
        }

        // Update score (clamped between 0-100)
        double newScore = (currentScore + scoreAdjustment).clamp(0.0, 100.0);

        transaction.update(userDoc, {'drivingScore': newScore});

        print('📊 Driving Score Updated:');
        print('   Previous: ${currentScore.toStringAsFixed(1)}');
        print('   New: ${newScore.toStringAsFixed(1)}');
        print('   Adjustment: ${scoreAdjustment > 0 ? '+' : ''}${scoreAdjustment.toStringAsFixed(1)}');
        print('   Performance: $performance');
        print('   Harsh events/min: ${harshEventsPerMinute.toStringAsFixed(2)}');
      });
    } catch (e) {
      print('❌ Failed to update driving score: $e');
      rethrow;
    }
  }

  /// Get current driving score for a user
  static Future<double?> getDrivingScore(String userId) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final snapshot = await firestore.collection('users').doc(userId).get();

      if (!snapshot.exists) return null;

      return (snapshot.data()?['drivingScore'] ?? 50.0).toDouble();
    } catch (e) {
      print('❌ Failed to get driving score: $e');
      return null;
    }
  }

  /// Initialize driving score for new user
  static Future<void> initializeDrivingScore(String userId) async {
    try {
      final firestore = FirebaseFirestore.instance;
      await firestore.collection('users').doc(userId).set(
        {'drivingScore': 50.0},
        SetOptions(merge: true),
      );
      print('✅ Driving score initialized to 50.0 for user $userId');
    } catch (e) {
      print('❌ Failed to initialize driving score: $e');
      rethrow;
    }
  }
}