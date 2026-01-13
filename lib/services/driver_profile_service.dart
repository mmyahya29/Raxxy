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
          .limit(sessionCount)
          .get();

      if (sessionsSnapshot.docs.isEmpty) {
        return getDefaultProfile();
      }

      final sessions = sessionsSnapshot.docs.map((doc) => doc.data()).toList();

      // Calculating metrics from sessions
      final metrics = _calculateMetrics(sessions);

      // Determine primary profile
      final primaryProfile = _determinePrimaryProfile(metrics);

      // Determine secondary traits
      final secondaryTraits = _determineSecondaryTraits(metrics, sessions);

      // NEW: Identify Stress Triggers
      final stressTriggers = _identifyStressTriggers(sessions, metrics);

      // Calculate profile scores
      final scores = _calculateProfileScores(metrics);

      // Generate recommendations
      final recommendations = _generateRecommendations(primaryProfile, metrics, stressTriggers);

      // Calculate badge tier
      final badge = _calculateBadgeTier(metrics);

      return {
        'primaryProfile': primaryProfile,
        'secondaryTraits': secondaryTraits,
        'stressTriggers': stressTriggers, // Saved to profile
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

  /// NEW: Logic to identify specific stress triggers
  static List<String> _identifyStressTriggers(
      List<Map<String, dynamic>> sessions, Map<String, double> overallMetrics) {
    final triggers = <String>[];
    final overallHarshRate = overallMetrics['avgHarshEventsPerMin'] ?? 0.0;

    // Avoid noise for perfect drivers or very low sample size
    if (overallHarshRate < 0.05) return triggers;

    // 1. Time-of-Day Analysis
    // Buckets: 0=Night(22-6), 1=Morning(6-10), 2=Midday(10-16), 3=Evening(16-22)
    final timeBuckets = List.generate(4, (_) => {'count': 0, 'harsh': 0.0});

    for (var session in sessions) {
      // Handle timestamp properly
      final endTimestamp = session['endTime'] as Timestamp?;
      if (endTimestamp == null) continue;

      final date = endTimestamp.toDate();
      final hour = date.hour;
      final harsh = ((session['harshAccelerations'] ?? 0) + (session['harshBrakes'] ?? 0)).toDouble();
      final duration = (session['durationMinutes'] ?? 1).toDouble();
      final harshRate = duration > 0 ? harsh / duration : 0;

      int bucketIndex;
      if (hour >= 6 && hour < 10) bucketIndex = 1; // Morning Rush
      else if (hour >= 10 && hour < 16) bucketIndex = 2; // Midday
      else if (hour >= 16 && hour < 22) bucketIndex = 3; // Evening Rush
      else bucketIndex = 0; // Night

      timeBuckets[bucketIndex]['count'] = (timeBuckets[bucketIndex]['count'] as int) + 1;
      timeBuckets[bucketIndex]['harsh'] = (timeBuckets[bucketIndex]['harsh'] as double) + harshRate;
    }

    // Average out the buckets
    for (int i = 0; i < timeBuckets.length; i++) {
      int count = timeBuckets[i]['count'] as int;
      if (count > 0) {
        timeBuckets[i]['harsh'] = (timeBuckets[i]['harsh'] as double) / count;
      }
    }

    // Define Thresholds (30% higher than average)
    if ((timeBuckets[1]['harsh'] as double) > overallHarshRate * 1.3) triggers.add('Morning Rush (6-10 AM)');
    if ((timeBuckets[3]['harsh'] as double) > overallHarshRate * 1.3) triggers.add('Evening Traffic (4-10 PM)');
    if ((timeBuckets[0]['harsh'] as double) > overallHarshRate * 1.5) triggers.add('Late Night Driving');

    // 2. Traffic Density Inference
    // We infer "Heavy Traffic" if avgSpeed is low (< 35km/h) BUT stop-and-go (switches > 4/min) is high
    double heavyTrafficHarshRate = 0;
    int heavyTrafficCount = 0;

    for (var session in sessions) {
      final avgSpeed = (session['avgSpeedKmh'] ?? 0).toDouble();
      final switches = (session['totalSwitches'] ?? 0).toDouble();
      final duration = (session['durationMinutes'] ?? 1).toDouble();
      final switchesPerMin = duration > 0 ? switches / duration : 0;

      final harsh = ((session['harshAccelerations'] ?? 0) + (session['harshBrakes'] ?? 0)).toDouble();
      final harshRate = duration > 0 ? harsh / duration : 0;

      if (avgSpeed < 35 && switchesPerMin > 4.0) {
        heavyTrafficHarshRate += harshRate;
        heavyTrafficCount++;
      }
    }

    if (heavyTrafficCount > 0) {
      final avgHeavyTrafficHarsh = heavyTrafficHarshRate / heavyTrafficCount;
      if (avgHeavyTrafficHarsh > overallHarshRate * 1.25) {
        triggers.add('Heavy Traffic');
      }
    }

    // 3. Long Duration Fatigue
    double longDriveHarshRate = 0;
    int longDriveCount = 0;

    for (var session in sessions) {
      final duration = (session['durationMinutes'] ?? 0).toDouble();
      if (duration > 45) {
        final harsh = ((session['harshAccelerations'] ?? 0) + (session['harshBrakes'] ?? 0)).toDouble();
        longDriveHarshRate += harsh / duration;
        longDriveCount++;
      }
    }

    if (longDriveCount > 0 && (longDriveHarshRate / longDriveCount) > overallHarshRate * 1.3) {
      triggers.add('Long Drives (>45m)');
    }

    return triggers;
  }

  /// Calculate profiling metrics from sessions
  static Map<String, double> _calculateMetrics(List<Map<String, dynamic>> sessions) {
    if (sessions.isEmpty) return {};

    double totalHighwayProb = 0;
    double totalCityProb = 0;
    double totalHarshEvents = 0;
    double totalAvgSpeed = 0;
    double totalMaxSpeed = 0;
    double totalSwitches = 0;
    double totalDuration = 0;
    double totalDistance = 0;
    double totalTurns = 0;

    List<double> harshEventRates = [];
    List<double> avgSpeeds = [];

    for (var session in sessions) {
      final duration = (session['durationMinutes'] ?? 0).toDouble();
      if (duration == 0) continue;

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

    final avgHighwayProb = totalHighwayProb / count;
    final avgCityProb = totalCityProb / count;
    final double avgHarshEventsPerMin = totalDuration > 0 ? totalHarshEvents / totalDuration : 0;
    final avgSpeed = totalAvgSpeed / count;
    final avgMaxSpeed = totalMaxSpeed / count;
    final double avgSwitchesPerMin = totalDuration > 0 ? totalSwitches / totalDuration : 0;
    final double avgTurnsPerMin = totalDuration > 0 ? totalTurns / totalDuration : 0;

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

  static String _determinePrimaryProfile(Map<String, double> metrics) {
    final highwayProb = metrics['avgHighwayProbability'] ?? 0.0;
    final cityProb = metrics['avgCityProbability'] ?? 0.0;
    final harshEvents = metrics['avgHarshEventsPerMin'] ?? 0.0;
    final avgSpeed = metrics['avgSpeed'] ?? 0.0;

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
      return harshEvents < 0.3 ? 'City Expert' : 'Urban Rusher';
    }

    return 'Balanced Driver';
  }

  static List<String> _determineSecondaryTraits(
      Map<String, double> metrics, List<Map<String, dynamic>> sessions) {
    List<String> traits = [];
    final harshEvents = metrics['avgHarshEventsPerMin'] ?? 0.0;
    final switchesPerMin = metrics['avgSwitchesPerMin'] ?? 0.0;
    final avgSpeed = metrics['avgSpeed'] ?? 0.0;
    final consistency = metrics['consistencyScore'] ?? 0.0;

    bool isNightOwl = false;
    int nightSessions = 0;
    for (var session in sessions) {
      final endTime = (session['endTime'] as Timestamp?)?.toDate();
      if (endTime != null && (endTime.hour < 6 || endTime.hour > 22)) {
        nightSessions++;
      }
    }
    if (nightSessions > sessions.length * 0.4) {
      traits.add('Night Owl');
    }

    if (harshEvents < 0.1 && switchesPerMin < 2) traits.add('Calm Driver');
    if (switchesPerMin > 6 && harshEvents < 0.3) traits.add('Traffic Warrior');
    if (switchesPerMin < 3 && harshEvents < 0.2) traits.add('Smooooth Operatoorrr 🌶️');
    if (consistency > 0.75) traits.add('Consistent');
    else if (consistency < 0.4) traits.add('Inconsistent');

    final trend = _calculateTrend(sessions);
    if (trend > 0.15) traits.add('Improving Fast');
    else if (trend > 0.05) traits.add('Improving');
    else if (trend < -0.15) traits.add('Needs Focus');

    if (harshEvents < 0.2 && avgSpeed > 40 && avgSpeed < 70) traits.add('Fuel Efficient');
    if (metrics['avgCityProbability']! > 0.6 && switchesPerMin > 5 && harshEvents < 0.35) {
      traits.add('Rush Hour Expert');
    }

    return traits;
  }

  static Map<String, int> _calculateProfileScores(Map<String, double> metrics) {
    final harshEvents = metrics['avgHarshEventsPerMin'] ?? 0.0;
    final avgSpeed = metrics['avgSpeed'] ?? 0.0;
    final consistency = metrics['consistencyScore'] ?? 0.0;

    int smoothness = ((1.0 - (harshEvents * 1.5).clamp(0.0, 1.0)) * 100).round();

    double safetyFactor = 1.0;
    if (avgSpeed > 110) safetyFactor -= 0.3;
    if (harshEvents > 0.5) safetyFactor -= 0.4;
    int safety = (safetyFactor * 100).clamp(0, 100).round();

    double efficiencyFactor = 0.5;
    if (avgSpeed > 40 && avgSpeed < 90) efficiencyFactor += 0.3;
    if (harshEvents < 0.2) efficiencyFactor += 0.2;
    int efficiency = (efficiencyFactor * 100).clamp(0, 100).round();

    int consistencyScore = (consistency * 100).round();
    int overall = ((smoothness + safety + efficiency + consistencyScore) / 4).round();

    return {
      'smoothness': smoothness,
      'safety': safety,
      'efficiency': efficiency,
      'consistency': consistencyScore,
      'overall': overall,
    };
  }

  static List<String> _generateRecommendations(
      String profile, Map<String, double> metrics, [List<String>? triggers]) {
    final recommendations = <String>[];
    final harshEvents = metrics['avgHarshEventsPerMin'] ?? 0.0;
    final avgSpeed = metrics['avgSpeed'] ?? 0.0;
    final switchesPerMin = metrics['avgSwitchesPerMin'] ?? 0.0;

    // Trigger-based recommendations (Real-time relevance)
    if (triggers != null && triggers.isNotEmpty) {
      for (var trigger in triggers) {
        if (trigger.contains('Morning Rush')) {
          recommendations.add('🌅 Try leaving 10 minutes earlier to avoid Morning Rush stress');
        } else if (trigger.contains('Evening Traffic')) {
          recommendations.add('🏙️ Patience is key in Evening Traffic. Deep breaths!');
        } else if (trigger.contains('Heavy Traffic')) {
          recommendations.add('🚗 In Heavy Traffic, increase following distance to avoid sudden stops');
        } else if (trigger.contains('Late Night')) {
          recommendations.add('🌙 Night visibility is lower. Reduce speed slightly.');
        } else if (trigger.contains('Long Drives')) {
          recommendations.add('⏱️ Take a break every 2 hours on long drives to stay fresh.');
        }
      }
    }

    switch (profile) {
      case 'Aggressive Driver':
        recommendations.add('🚦 Maintain safe following distance to reduce harsh braking');
        recommendations.add('🧘 Practice smooth acceleration - anticipate traffic flow');
        break;
      case 'Cautious Driver':
        recommendations.add('🚗 Consider gradually increasing highway driving for experience');
        break;
      case 'City Expert':
        recommendations.add('✅ Your smooth city driving is exemplary');
        break;
      case 'Highway Cruiser':
        recommendations.add('✅ Your long-distance driving is efficient');
        break;
      case 'Struggling Driver':
        recommendations.add('🎓 Consider defensive driving course');
        recommendations.add('🚦 Focus on maintaining steady speed');
        break;
      default:
        recommendations.add('🚗 Keep driving to build your profile');
    }

    if (harshEvents > 0.4) recommendations.add('⚠️ Reduce harsh events by 30% to improve fuel efficiency');
    if (switchesPerMin > 7) recommendations.add('🔄 Try smoother transitions between acceleration and braking');
    if (avgSpeed < 30) recommendations.add('🐌 Consider route planning to avoid heavy congestion');

    return recommendations;
  }

  static Map<String, dynamic> _calculateBadgeTier(Map<String, double> metrics) {
    final harshEvents = metrics['avgHarshEventsPerMin'] ?? 0.0;
    final consistency = metrics['consistencyScore'] ?? 0.0;
    final distance = metrics['totalDistance'] ?? 0.0;

    String tier;
    String emoji;
    String description;

    if (harshEvents < 0.15 && consistency > 0.75 && distance > 100) {
      tier = 'Diamond'; emoji = '💎'; description = 'Elite Driver - Exceptional Skill';
    } else if (harshEvents < 0.25 && consistency > 0.65 && distance > 50) {
      tier = 'Platinum'; emoji = '🏆'; description = 'Expert Driver - Highly Skilled';
    } else if (harshEvents < 0.35 && consistency > 0.55) {
      tier = 'Gold'; emoji = '🥇'; description = 'Skilled Driver - Above Average';
    } else if (harshEvents < 0.5 && consistency > 0.45) {
      tier = 'Silver'; emoji = '🥈'; description = 'Competent Driver - Improving';
    } else {
      tier = 'Bronze'; emoji = '🥉'; description = 'Developing Driver - Keep Practicing';
    }

    return {'tier': tier, 'emoji': emoji, 'description': description};
  }

  static double _calculateVariance(List<double> numbers) {
    if (numbers.isEmpty) return 0;
    final mean = numbers.reduce((a, b) => a + b) / numbers.length;
    final variance = numbers.map((n) => pow(n - mean, 2)).reduce((a, b) => a + b) / numbers.length;
    return variance;
  }

  static double _calculateConsistency(double speedVar, double harshVar) {
    final speedConsistency = (1.0 - (speedVar / 400).clamp(0.0, 1.0));
    final harshConsistency = (1.0 - (harshVar / 0.5).clamp(0.0, 1.0));
    return (speedConsistency + harshConsistency) / 2;
  }

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

    return olderAvg - recentAvg;
  }

  static Map<String, dynamic> getDefaultProfile() {
    return {
      'primaryProfile': 'New Driver',
      'secondaryTraits': ['Getting Started'],
      'stressTriggers': [], // Empty for new users
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