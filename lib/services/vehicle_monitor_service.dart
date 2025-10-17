import 'dart:async';
import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:raxxy/services/crash_detector.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../providers/provider.dart';
import 'notifications_services.dart';

class VehicleMonitorService {
  final ValueNotifier<String?> monitoredVehicleIdNotifier = ValueNotifier(null);
  final ValueNotifier<double> currentSpeedNotifier = ValueNotifier(0.0);
  final ValueNotifier<double> currentAccelerationNotifier = ValueNotifier(0.0);
  final ValueNotifier<double> currentDistanceNotifier = ValueNotifier(0.0);

  static final VehicleMonitorService _instance = VehicleMonitorService._internal();
  factory VehicleMonitorService() => _instance;
  VehicleMonitorService._internal();

  StreamSubscription<UserAccelerometerEvent>? _accelSub;
  StreamSubscription<Position>? _positionSub;

  UserAccelerometerEvent? currentAcceleration;
  double currentSpeedKmh = 0.0;

  final List<Map<String, dynamic>> _speedHistory = [];

  double totalDistanceMeters = 0.0;
  Position? _lastPosition;

  bool _isMonitoring = false;

  final double accelerationThreshold = 1.5;
  final double decelerationThreshold = -1.5;

  final List<double> _accelBuffer = [];
  final int _acBufferSize = 20;

  String? _userId;
  String? _vehicleId;

  //Variables for session summary
  DateTime? _sessionStart;
  DateTime? _sessionEnd;

  double _maxSpeed = 0.0;
  double _speedSum = 0.0;
  int _speedCount = 0;

  int _harshAccelEvents = 0;
  int _harshBrakeEvents = 0;


  Future<void> startMonitoring({
    required BuildContext context,
    required String userId,
    required String vehicleId,
    required String make,
    required String model,
    required WidgetRef ref,
  }) async {
    if (_isMonitoring) return;
    _isMonitoring = true;
    _userId = userId;
    _vehicleId = vehicleId;

    //session summary values reset
    _sessionStart = DateTime.now();
    _sessionEnd = null;
    _maxSpeed = 0.0;
    _speedSum = 0.0;
    _speedCount = 0;
    _harshAccelEvents = 0;
    _harshBrakeEvents = 0;


    ref.read(vehicleMonitorProvider.notifier).setVehicle(vehicleId);
    ref.read(vehicleMonitorProvider.notifier).setMake(make);
    ref.read(vehicleMonitorProvider.notifier).setModel(model);

    sendNotification("RAXXY", "Monitoring service started");


    _accelSub = userAccelerometerEvents.listen((event) {
      currentAcceleration = event;

      // Only horizontal movement (X and Y)
      double horizontalAccel = sqrt(event.x *event.x + event.y * event.y);
      if((event.x+event.y)<0){
        horizontalAccel*=-1;
      }
      // double horizontalDecel = event.y;

      _accelBuffer.add(horizontalAccel);
      if (_accelBuffer.length > _acBufferSize) {
        _accelBuffer.removeAt(0); // keep buffer size fixed
      }

      int negcount=0;
      int poscount=0;
      for(int i=0; i<_accelBuffer.length-1; i++){
        if((_accelBuffer[i]<0)&&(_accelBuffer[i+1]>0)){
          negcount++;
        }else{
          poscount++;
        }
      }

      double avgAccel = _accelBuffer.reduce((a, b) => a + b) / _accelBuffer.length;
      if(negcount>poscount)
        avgAccel*=-1;

      ref.read(vehicleMonitorProvider.notifier).updateAcceleration(avgAccel);

      if (avgAccel > accelerationThreshold) {
        _harshAccelEvents++;
        sendNotification("Woah Buddy! Easy on the Gas", "Acceleration: ${avgAccel.toStringAsFixed(2)} m/s²");
      } else if (avgAccel < decelerationThreshold) {
        _harshBrakeEvents++;
        sendNotification("Woah Buddy! Easy on the Brakes", "Deceleration: ${avgAccel.toStringAsFixed(2)} m/s²");
      }
    });

    // Check location permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.always && permission != LocationPermission.whileInUse) {
        print('Location permission not granted');
        return;
      }
    }



    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 1,
      ),
    ).listen((position) async {
      final now =DateTime.now();
      currentSpeedKmh = position.speed * 3.6;
      _maxSpeed = max(_maxSpeed, currentSpeedKmh);
      ref.read(vehicleMonitorProvider.notifier).updateSpeed(currentSpeedKmh);
      print('Speed: ${currentSpeedKmh.toStringAsFixed(2)} km/h');

      // Store speed with time for checking duration of speed drop // like 1 second mein more than 15 ka drop
      _speedHistory.add({
        'time': now,
        'speed': currentSpeedKmh,
      });
      if (_speedHistory.length > 10) _speedHistory.removeAt(0);

      // Check for sudden // woi jo 2 length rkhi thi speed buffer ki
      if (_speedHistory.length >= 2) {
        // getting last two readings and unka time
        final recent = _speedHistory[_speedHistory.length - 1];
        final previous = _speedHistory[_speedHistory.length - 2];

        final delTime = recent['time'].difference(previous['time']).inMilliseconds / 1000.0;
        final delSpeed = recent[
        'speed'] - previous['speed'];

        // woi acceleration buffer but instead saari k oper iterate kren we'll only check the last two, these will always be the most recent ones
        double accelFluctuation = _accelBuffer.last - _accelBuffer[_accelBuffer.length - 2];

        if ((delSpeed < -15 && delTime < 1.5)||(accelFluctuation.abs()>3)) {
          sendNotification("Crash Detected", "Possible impact detected");
          // Idr ap crash detect hony k baad jo krna hai wo kr skty ho
          CrashDetector.checkForCrash(context);
        }
      }



      if (_lastPosition != null) {
        double distance = Geolocator.distanceBetween(
          _lastPosition!.latitude,
          _lastPosition!.longitude,
          position.latitude,
          position.longitude,
        );

        totalDistanceMeters += distance;
        ref.read(vehicleMonitorProvider.notifier).updateDistance(totalDistanceMeters);
        print('Distance: ${distance.toStringAsFixed(2)} m, Total: ${totalDistanceMeters.toStringAsFixed(2)} m');

        await _updateVehicleMileage(distance);
      }

      _lastPosition = position;
    });

    print('Monitoring started');
  }

  Future<void> _updateVehicleMileage(double distanceMeters) async {
    if (_userId == null || _vehicleId == null) return;

    final firestore = FirebaseFirestore.instance;
    final docRef = firestore.collection('users').doc(_userId).collection('vehicles').doc(_vehicleId);

    final snapshot = await docRef.get();
    if (!snapshot.exists) return;

    double currentMileage = snapshot['mileage']?.toDouble() ?? 0.0;
    double distanceKm = distanceMeters / 1000.0;

    await docRef.update({'mileage': currentMileage + distanceKm});
    print('Mileage updated: +${distanceKm.toStringAsFixed(2)} km');
  }

  void stopMonitoring(WidgetRef ref, double distance) async {
    _accelSub?.cancel();
    _positionSub?.cancel();
    _lastPosition = null;
    totalDistanceMeters = 0.0;
    _isMonitoring = false;

    final summary = generateSessionSummary();

    generateGoalFromSummary(summary);

    calculateDrivingScore(avgSpeed: summary["avgSpeed"], harshAccel: summary["harshAccelerations"], harshBrakes: summary["harshBrakes"], durationMinutes: summary["duration"]);

    //Save summary to Firestore
    final firestore = FirebaseFirestore.instance;
    await firestore.collection('users').doc(_userId)
        .collection('sessions').add(summary);

    final docRef = firestore.collection('users').doc(_userId).collection('vehicles').doc(_vehicleId);
    await docRef.update({'mileage': distance});

    ref.read(vehicleMonitorProvider.notifier).clear();

    print('Monitoring stopped');
    sendNotification("RAXXY", "Monitoring service stopped");
  }

  Map<String, dynamic> generateSessionSummary()  {
    _sessionEnd = DateTime.now();

    double avgSpeed = _speedCount > 0 ? _speedSum / _speedCount : 0.0;
    double distanceKm = totalDistanceMeters / 1000.0;
    Duration duration = _sessionEnd!.difference(_sessionStart!);

    return {
      "startTime": _sessionStart,
      "endTime": _sessionEnd,
      "duration": duration.inMinutes,
      "distanceKm": distanceKm,
      "maxSpeed": _maxSpeed,
      "avgSpeed": avgSpeed,
      "harshAccelerations": _harshAccelEvents,
      "harshBrakes": _harshBrakeEvents,
    };
  }

  Future<void> generateGoalFromSummary(Map<String, dynamic> summary) async {
    final firestore = FirebaseFirestore.instance;
    final userId = _userId;

    List<Map<String, dynamic>> current_goals =[] ;

    try {
      final querySnapshot = await firestore
          .collection('users')
          .doc(userId)
          .collection('goals')
          .get();

      current_goals = querySnapshot.docs
          .map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();

      print("Fetched ${current_goals.length} goals for user $userId");
    } catch (e) {
      print("Error fetching goals: $e");
    }

    final int accHarshEvents = (summary["harshAccelerations"] ?? 0);
    final int brHarshEvents = (summary["harshBrakes"] ?? 0);
    final int durationMinutes = summary["duration"] ?? 0;

    print(durationMinutes);

    if (durationMinutes == 0) return;

    double accEventsPerMinute = accHarshEvents / durationMinutes;
    print(accEventsPerMinute);
    double brEventsPerMinute = brHarshEvents / durationMinutes;
    print(brEventsPerMinute);

    //Deleting completed goals
    for (var goal in current_goals) {
      if ((goal["title"] == "Improve Smooth Throttle" &&
          goal["target"] ==
              "Drive with fewer than ${durationMinutes * 0.2} harsh events" &&
          accEventsPerMinute < 0.2)||(goal["title"] == "Improve Smooth Braking" &&
          goal["target"] ==
              "Drive with fewer than ${durationMinutes * 0.2} harsh events" &&
          brEventsPerMinute < 0.2)) {

        await firestore
            .collection('users')
            .doc(userId)
            .collection('goals')
            .doc(goal["id"])
            .delete();

        print("Goal completed and deleted: ${goal['title']}");
      }
    }

    //If more than 0.2 events per minute, add a goal
    if (accEventsPerMinute > 0.2) {
      final goal = {
        "vehicleId": _vehicleId,
        "title": "Improve Smooth Throttle",
        "description": "Reduce harsh acceleration in your next trips.",
        "createdAt": FieldValue.serverTimestamp(),
        "target": "Drive with fewer than ${durationMinutes * 0.2} harsh events",
      };

      if(current_goals.isNotEmpty&&(!goalExists(current_goals, goal))){
        await firestore.collection("users").doc(userId).collection("goals").add(goal);
        print("New goal generated: $goal");
      }
    }

    if (brEventsPerMinute > 0.2) {
      final goal = {
        "vehicleId": _vehicleId,
        "title": "Improve Smooth Braking",
        "description": "Reduce harsh braking in your next trips.",
        "createdAt": FieldValue.serverTimestamp(),
        "target": "Drive with fewer than ${durationMinutes * 0.2} harsh events",
      };

      if(current_goals.isNotEmpty&&(!goalExists(current_goals, goal))){
        await firestore.collection("users").doc(userId).collection("goals").add(goal);
        print("New goal generated: $goal");
      }
    }
  }

  bool goalExists(List<Map<String, dynamic>> goals, Map<String, dynamic> newGoal) {
    return goals.any((g) =>
    g["title"] == newGoal["title"] &&
        g["target"] == newGoal["target"]);
  }

  Future<void> calculateDrivingScore({
    required double avgSpeed,
    required int harshAccel,
    required int harshBrakes,
    required int durationMinutes,
  }) async {
    final firestore = FirebaseFirestore.instance;
    final userId = _userId;
    if (userId == null) return;

    double sessionScore = 100.0;

    // Penalize harsh events / kaand pr danda x1
    int totalHarshEvents = harshAccel + harshBrakes;
    sessionScore -= totalHarshEvents * 2;

    // Penalize unsafe speeds / kaand pr danda x2
    if (avgSpeed > 100) {
      sessionScore -= (avgSpeed - 100) * 0.5; // too fast /DU DU DUDU
    } else if (avgSpeed < 20) {
      sessionScore -= (20 - avgSpeed) * 0.3; // too slow / stop-go / bich mein jaanu k msgs dekhny lg gya
    }

    // reward for longer trips /  not kaand pr itna tw chala k mereko kuch pta chly
    if (durationMinutes > 30) {
      sessionScore += 3;
    } else if (durationMinutes < 5) {
      sessionScore -= 5; // too short to judge, thats what she said
    }

    sessionScore = sessionScore.clamp(0, 100); // dis shit clamps score from 0-100 / Its obvious dumbass, y u sweating to mention it?

    // Get current score
    final userDoc = firestore.collection('users').doc(userId);
    final snapshot = await userDoc.get();
    double currentScore = (snapshot.data()?['drivingScore'] ?? 50).toDouble(); // if not then return 50

    // Weighted update, Ik session ka Score gradually effect kry ga total score ko so *0.1
    double newGlobalScore = currentScore + (sessionScore - 50) * 0.1;
    newGlobalScore = newGlobalScore.clamp(0, 100);


    await userDoc.set({'drivingScore': newGlobalScore}, SetOptions(merge: true));

    print('Session Score: $sessionScore');
    print('Updated Global Driving Score: $newGlobalScore');
  }


  bool get isMonitoring => _isMonitoring;
}
