import 'dart:async';
import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  double totalDistanceMeters = 0.0;
  Position? _lastPosition;

  bool _isMonitoring = false;

  final double accelerationThreshold = 2.4;
  final double decelerationThreshold = -2.4;

  final List<double> _accelBuffer = [];
  final int _bufferSize = 10;

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
      double horizontalAccel = sqrt(event.x * event.x + event.y * event.y);

      _accelBuffer.add(horizontalAccel);
      if (_accelBuffer.length > _bufferSize) {
        _accelBuffer.removeAt(0); // keep buffer size fixed
      }

      double avgAccel = _accelBuffer.reduce((a, b) => a + b) / _accelBuffer.length;

      ref.read(vehicleMonitorProvider.notifier).updateAcceleration(avgAccel);

      if (avgAccel > accelerationThreshold) {
        _harshAccelEvents++;
        sendNotification("Woah Buddy! Easy on the Gas", "Acceleration: ${avgAccel.toStringAsFixed(2)} m/s²");
      } else if (avgAccel < decelerationThreshold) {
        _harshBrakeEvents++;
        sendNotification("Woah Buddy! Easy on the Brakes", "Deceleration: ${avgAccel.toStringAsFixed(2)} m/s²");
      }

      print('Smoothed Horizontal Acceleration (moving avg): ${avgAccel.toStringAsFixed(2)} m/s²');
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
      currentSpeedKmh = position.speed * 3.6;
      _maxSpeed = max(_maxSpeed, currentSpeedKmh);
      ref.read(vehicleMonitorProvider.notifier).updateSpeed(currentSpeedKmh);
      print('Speed: ${currentSpeedKmh.toStringAsFixed(2)} km/h');

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

    // Optional: Save summary to Firestore
    final firestore = FirebaseFirestore.instance;
    await firestore.collection('users').doc(_userId)
        .collection('sessions').add(summary);

    final docRef = firestore.collection('users').doc(_userId).collection('vehicles').doc(_vehicleId);
    await docRef.update({'mileage': distance});

    ref.read(vehicleMonitorProvider.notifier).clear();

    print('Monitoring stopped');
    sendNotification("RAXXY", "Monitoring service stopped");
  }

  Map<String, dynamic> generateSessionSummary() {
    _sessionEnd = DateTime.now();

    double avgSpeed = _speedCount > 0 ? _speedSum / _speedCount : 0.0;
    double distanceKm = totalDistanceMeters / 1000.0;
    Duration duration = _sessionEnd!.difference(_sessionStart!);

    return {
      "vehicleId": _vehicleId,
      "startTime": _sessionStart.toString(),
      "endTime": _sessionEnd.toString(),
      "duration": duration.inMinutes.toString() + " mins",
      "distanceKm": distanceKm.toStringAsFixed(2),
      "maxSpeed": _maxSpeed.toStringAsFixed(2),
      "avgSpeed": avgSpeed.toStringAsFixed(2),
      "harshAccelerations": _harshAccelEvents,
      "harshBrakes": _harshBrakeEvents,
    };
  }


  bool get isMonitoring => _isMonitoring;
}
