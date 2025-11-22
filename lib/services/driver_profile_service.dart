import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

class DriverProfileService {
  // Analyze last 10 sessions and generate driver profile
  static Future<Map<String, dynamic>> analyzeDriverProfile({
    required String userId,
    int sessionCount = 10,
  }) async {
    try {
      final firestore = FirebaseFirestore.instance;

      // Get last 10 sessions
      final sessionsSnapshot = await firestore
          .collection('users')
          .doc(userId)
          .collection('sessions')
          .orderBy('endTime', descending: true)
          .limit(sessionCount) // session limit iz 10
          .get();

      if (sessionsSnapshot.docs.isEmpty) {
        return getDefaultProfile(); //default base profile, nichy function bna va
      }

      final sessions = sessionsSnapshot.docs.map((doc) => doc.data()).toList(); //converting snapshot to list, use krny k liye

      // Calculating metrics from sessions
      final metrics = _calculateMetrics(sessions);

      // Determine primary profile
      final primaryProfile = _determinePrimaryProfile(metrics);

      // Determine secondary traits
      final secondaryTraits = _determineSecondaryTraits(metrics, sessions);

      // Calculate profile scores
      final scores = _calculateProfileScores(metrics);

      // Generate recommendations
      final recommendations = _generateRecommendations(primaryProfile, metrics);

      // Calculate badge tier
      final badge = _calculateBadgeTier(metrics);

      return {
        'primaryProfile': primaryProfile,
        'secondaryTraits': secondaryTraits,
        'metrics': metrics,
        'scores': scores,
        'recommendations': recommendations,
        'badge': badge,
        'analyzedSessions': sessions.length,
        'lastAnalyzed': Timestamp.now(),
      };
    } catch (e) {
      print('❌ Error analyzing driver profile: $e');
      return getDefaultProfile();
    }
  }

  /// Calculate profiling metrics from sessions
  static Map<String, double> _calculateMetrics(List<Map<String, dynamic>> sessions) {
    if (sessions.isEmpty) return {};

    // Initialize sums
    double totalHighwayProb = 0;
    double totalCityProb = 0;
    double totalHarshEvents = 0;
    double totalAvgSpeed = 0;
    double totalMaxSpeed = 0;
    double totalSwitches = 0;
    double totalDuration = 0;
    double totalDistance = 0;
    double totalTurns = 0;

    List<double> drivingScores = [];
    List<double> harshEventRates = [];
    List<double> avgSpeeds = [];

    for (var session in sessions) {
      final duration = (session['durationMinutes'] ?? 0).toDouble();
      if (duration == 0) continue; //remember 'continue'?

      totalHighwayProb += (session['highwayProbability'] ?? 0.0);
      totalCityProb += (session['cityProbability'] ?? 0.0);
      totalHarshEvents += ((session['harshAccelerations'] ?? 0) + (session['harshBrakes'] ?? 0)).toDouble();
      totalAvgSpeed += (session['avgSpeedKmh'] ?? 0.0);
      totalMaxSpeed += (session['maxSpeedKmh'] ?? 0.0);
      totalSwitches += (session['totalSwitches'] ?? 0).toDouble();
      totalDuration += duration;
      totalDistance += (session['distanceKm'] ?? 0.0);
      totalTurns += (session['totalTurns'] ?? 0).toDouble();

      harshEventRates.add((session['harshEventsPerMinute'] ?? 0.0));
      avgSpeeds.add((session['avgSpeedKmh'] ?? 0.0));
    }

    final count = sessions.length.toDouble();

    // Calculate averages
    final avgHighwayProb = totalHighwayProb / count;
    final avgCityProb = totalCityProb / count;
    final double avgHarshEventsPerMin = totalDuration > 0 ? totalHarshEvents / totalDuration : 0;
    final avgSpeed = totalAvgSpeed / count;
    final avgMaxSpeed = totalMaxSpeed / count;
    final double avgSwitchesPerMin = totalDuration > 0 ? totalSwitches / totalDuration : 0;
    final double avgTurnsPerMin = totalDuration > 0 ? totalTurns / totalDuration : 0;

    // Calculate variance/consistency
    final speedVariance = _calculateVariance(avgSpeeds);
    final harshEventVariance = _calculateVariance(harshEventRates);

    return {
      'avgHighwayProbability': avgHighwayProb,
      'avgCityProbability': avgCityProb,
      'avgHarshEventsPerMin': avgHarshEventsPerMin,
      'avgSpeed': avgSpeed,
      'avgMaxSpeed': avgMaxSpeed,
      'avgSwitchesPerMin': avgSwitchesPerMin,
      'avgTurnsPerMin': avgTurnsPerMin,
      'totalDistance': totalDistance,
      'totalDuration': totalDuration,
      'speedVariance': speedVariance,
      'harshEventVariance': harshEventVariance,
      'consistencyScore': _calculateConsistency(speedVariance, harshEventVariance),
    };
  }

  /// Determine primary driving profile
  static String _determinePrimaryProfile(Map<String, double> metrics) {
    final highwayProb = metrics['avgHighwayProbability'] ?? 0.0;
    final cityProb = metrics['avgCityProbability'] ?? 0.0;
    final harshEvents = metrics['avgHarshEventsPerMin'] ?? 0.0;
    final avgSpeed = metrics['avgSpeed'] ?? 0.0;

    // Decision tree for primary profile
    if (harshEvents > 0.5) {
      return avgSpeed > 60 ? 'Aggressive Driver' : 'Struggling Driver';
    }

    if (harshEvents < 0.15) {
      if (avgSpeed < 35) {
        return 'Cautious Driver';
      } else if (avgSpeed > 65) {
        return 'Precision Driver';
      }
    }

    if (highwayProb > 0.65 && cityProb < 0.35) {
      return harshEvents < 0.25 ? 'Highway Cruiser' : 'Highway Speedster';
    }

    if (cityProb > 0.65 && highwayProb < 0.35) {
      return harshEvents < 0.3 ? 'City Expert' : 'City Struggler';
    }

    if ((highwayProb - cityProb).abs() < 0.2) {
      return harshEvents < 0.25 ? 'Balanced Driver' : 'Inconsistent Driver';
    }

    return 'Developing Driver';
  }

  /// Determine secondary traits
  static List<String> _determineSecondaryTraits(
      Map<String, double> metrics,
      List<Map<String, dynamic>> sessions,
      ) {
    final traits = <String>[];

    final avgSpeed = metrics['avgSpeed'] ?? 0.0;
    final harshEvents = metrics['avgHarshEventsPerMin'] ?? 0.0;
    final switchesPerMin = metrics['avgSwitchesPerMin'] ?? 0.0;
    final consistency = metrics['consistencyScore'] ?? 0.0;

    // Speed Demon
    if (avgSpeed > 70) {
      traits.add('Speed Demon');
    }

    // Zen Driver
    if (harshEvents < 0.1 && switchesPerMin < 2) {
      traits.add('Calm Driver');
    }

    // Traffic Warrior
    if (switchesPerMin > 6 && harshEvents < 0.3) {
      traits.add('Traffic Warrior');
    }

    // Smooth Operator, especially for u, 😏
    if (switchesPerMin < 3 && harshEvents < 0.2) {
      traits.add('Smooooth Operatoorrr');
    }

    // Consistent Performance
    if (consistency > 0.75) {
      traits.add('Consistent');
    } else if (consistency < 0.4) {
      traits.add('Inconsistent');
    }

    // Check for improvement trend (compare first half vs second half)
    final trend = _calculateTrend(sessions);
    if (trend > 0.15) {
      traits.add('Improving Fast');
    } else if (trend > 0.05) {
      traits.add('Improving');
    } else if (trend < -0.15) {
      traits.add('Needs Focus');
    }

    // Economic Driver
    if (harshEvents < 0.2 && avgSpeed > 40 && avgSpeed < 70) {
      traits.add('Fuel Efficient');
    }

    // Rush Hour Expert
    if (metrics['avgCityProbability']! > 0.6 && switchesPerMin > 5 && harshEvents < 0.35) {
      traits.add('Rush Hour Expert');
    }

    return traits;
  }

  /// Calculate profile scores (0-100)
  static Map<String, int> _calculateProfileScores(Map<String, double> metrics) {
    final harshEvents = metrics['avgHarshEventsPerMin'] ?? 0.0;
    final avgSpeed = metrics['avgSpeed'] ?? 0.0;
    final consistency = metrics['consistencyScore'] ?? 0.0;

    // Smoothness Score (0-100)
    final smoothness = ((1 - (harshEvents / 1.0).clamp(0.0, 1.0)) * 100).toInt();

    // Safety Score (0-100)
    final safety = ((1 - (harshEvents / 0.8).clamp(0.0, 1.0)) * 100).toInt();

    // Efficiency Score (0-100) - Optimal speed 50-70 km/h
    final speedOptimal = (avgSpeed - 60).abs();
    final efficiency = ((1 - (speedOptimal / 40).clamp(0.0, 1.0)) * 100).toInt();

    // Consistency Score (0-100)
    final consistencyScore = (consistency * 100).toInt();

    // Overall Score (weighted average)
    final overall = ((smoothness * 0.3 + safety * 0.3 + efficiency * 0.2 + consistencyScore * 0.2)).toInt();

    return {
      'smoothness': smoothness,
      'safety': safety,
      'efficiency': efficiency,
      'consistency': consistencyScore,
      'overall': overall,
    };
  }

  /// Generate personalized recommendations
  static List<String> _generateRecommendations(String profile, Map<String, double> metrics) {
    final recommendations = <String>[];
    final harshEvents = metrics['avgHarshEventsPerMin'] ?? 0.0;
    final avgSpeed = metrics['avgSpeed'] ?? 0.0;
    final switchesPerMin = metrics['avgSwitchesPerMin'] ?? 0.0;

    switch (profile) {
      case 'Aggressive Driver':
        recommendations.add('🚦 Maintain safe following distance to reduce harsh braking');
        recommendations.add('🧘 Practice smooth acceleration - anticipate traffic flow');
        recommendations.add('⏱️ Leave earlier to reduce time pressure');
        break;

      case 'Cautious Driver':
        recommendations.add('🚗 Consider gradually increasing highway driving for experience');
        recommendations.add('📈 You\'re safe! Try maintaining traffic flow speed when conditions allow');
        break;

      case 'City Expert':
        recommendations.add('🛣️ Great city skills! Practice highway merging for versatility');
        recommendations.add('✅ Your smooth city driving is exemplary');
        break;

      case 'Highway Cruiser':
        recommendations.add('🏙️ Excellent highway skills! Practice urban navigation occasionally');
        recommendations.add('✅ Your long-distance driving is efficient');
        break;

      case 'Struggling Driver':
        recommendations.add('🎓 Consider defensive driving course');
        recommendations.add('🚦 Focus on maintaining steady speed and gentle inputs');
        recommendations.add('📍 Practice in low-traffic areas first');
        break;

      case 'Balanced Driver':
        recommendations.add('✅ Excellent versatility! Keep maintaining your balanced approach');
        recommendations.add('📊 Minor improvements can boost your efficiency further');
        break;

      case 'Precision Driver':
        recommendations.add('🏆 Outstanding! You\'re a role model driver');
        recommendations.add('💡 Consider sharing tips with other drivers');
        break;

      default:
        recommendations.add('📊 Keep driving to build your profile');
    }

    // Additional recommendations based on metrics
    if (harshEvents > 0.4) {
      recommendations.add('⚠️ Reduce harsh events by 30% to improve fuel efficiency');
    }

    if (switchesPerMin > 7) {
      recommendations.add('🔄 High acceleration changes detected - try smoother transitions');
    }

    if (avgSpeed < 30) {
      recommendations.add('🐌 Consider route planning to avoid heavy congestion');
    }

    return recommendations;
  }

  /// Calculate badge tier based on overall performance
  static Map<String, dynamic> _calculateBadgeTier(Map<String, double> metrics) {
    final harshEvents = metrics['avgHarshEventsPerMin'] ?? 0.0;
    final consistency = metrics['consistencyScore'] ?? 0.0;
    final distance = metrics['totalDistance'] ?? 0.0;

    String tier;
    String emoji;
    String description;

    if (harshEvents < 0.15 && consistency > 0.75 && distance > 100) {
      tier = 'Diamond';
      emoji = '💎';
      description = 'Elite Driver - Exceptional Skill';
    } else if (harshEvents < 0.25 && consistency > 0.65 && distance > 50) {
      tier = 'Platinum';
      emoji = '🏆';
      description = 'Expert Driver - Highly Skilled';
    } else if (harshEvents < 0.35 && consistency > 0.55) {
      tier = 'Gold';
      emoji = '🥇';
      description = 'Skilled Driver - Above Average';
    } else if (harshEvents < 0.5 && consistency > 0.45) {
      tier = 'Silver';
      emoji = '🥈';
      description = 'Competent Driver - Improving';
    } else {
      tier = 'Bronze';
      emoji = '🥉';
      description = 'Developing Driver - Keep Practicing';
    }

    return {
      'tier': tier,
      'emoji': emoji,
      'description': description,
    };
  }

  /// Calculate variance of a list
  static double _calculateVariance(List<double> values) {
    if (values.isEmpty) return 0;

    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance = values.map((v) => pow(v - mean, 2)).reduce((a, b) => a + b) / values.length;
    return sqrt(variance);
  }

  /// Calculate consistency score (0-1, higher is more consistent)
  static double _calculateConsistency(double speedVariance, double harshEventVariance) {
    // Lower variance, mtlb change kam, means higher consistency...
    final speedConsistency = 1 - (speedVariance / 50).clamp(0.0, 1.0);
    final harshConsistency = 1 - (harshEventVariance / 2).clamp(0.0, 1.0);
    return (speedConsistency + harshConsistency) / 2;
  }

  /// Calculate improvement trend
  static double _calculateTrend(List<Map<String, dynamic>> sessions) {
    if (sessions.length < 4) return 0;

    final half = sessions.length ~/ 2;
    final recentSessions = sessions.sublist(0, half);
    final olderSessions = sessions.sublist(half);

    final recentAvg = recentSessions
        .map((s) => (s['harshEventsPerMinute'] ?? 0.0) as double)
        .reduce((a, b) => a + b) / recentSessions.length;

    final olderAvg = olderSessions
        .map((s) => (s['harshEventsPerMinute'] ?? 0.0) as double)
        .reduce((a, b) => a + b) / olderSessions.length;

    // Negative trend = improving (fewer harsh events)
    return olderAvg - recentAvg;
  }

  /// Default profile for new users
  static Map<String, dynamic> getDefaultProfile() {
    return {
      'primaryProfile': 'New Driver',
      'secondaryTraits': ['Getting Started'],
      'metrics': {},
      'scores': {
        'smoothness': 50,
        'safety': 50,
        'efficiency': 50,
        'consistency': 50,
        'overall': 50,
      },
      'recommendations': [
        '🚗 Drive at least 10 sessions to generate your profile',
        '📊 Your driving patterns will be analyzed automatically',
      ],
      'badge': {
        'tier': 'Rookie',
        'emoji': '🆕',
        'description': 'New Driver - Building Experience',
      },
      'analyzedSessions': 0,
      'lastAnalyzed': Timestamp.now(),
    };
  }

  /// Save profile to Firestore
  static Future<void> saveProfile({
    required String userId,
    required Map<String, dynamic> profile,
  }) async {
    try {
      final firestore = FirebaseFirestore.instance;
      await firestore
          .collection('users')
          .doc(userId)
          .set({'driverProfile': profile}, SetOptions(merge: true));

      print('✅ Driver profile saved successfully');
    } catch (e) {
      print('❌ Failed to save driver profile: $e');
      rethrow;
    }
  }

  /// Get cached profile from Firestore
  static Future<Map<String, dynamic>?> getCachedProfile(String userId) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final doc = await firestore.collection('users').doc(userId).get();

      if (doc.exists && doc.data()?['driverProfile'] != null) {
        return doc.data()?['driverProfile'] as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('❌ Failed to get cached profile: $e');
      return null;
    }
  }
}