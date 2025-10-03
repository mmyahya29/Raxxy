import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';

typedef CrashCallback = void Function(Position pos, double lastSpeed, double currentSpeed);

class CrashDetector {
  Position? lastposition;
  double lastspeed = 0;
  DateTime? lasttime;
  StreamSubscription<Position>? posSub;
  final CrashCallback onCrashDetected;
  bool running = false;

  CrashDetector({required this.onCrashDetected});

  Future<void> start() async {
    if (running) return;
    running = true;

    LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
      timeLimit: null,
    );

    posSub = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position pos) {
      double currentSpeed = (pos.speed.isNaN) ? 0 : (pos.speed * 3.6);
      DateTime now = DateTime.now();

      if (lasttime != null) {
        double dt = now.difference(lasttime!).inMilliseconds / 1000.0;
        if (dt <= 3 && lastspeed >= 50 && currentSpeed <= 10) {
          onCrashDetected(pos, lastspeed, currentSpeed);
        }
      }

      lastspeed = currentSpeed;
      lastposition = pos;
      lasttime = now;
    }, onError: (e) {
      print("Position stream error: $e");
    });
  }

  Future<void> stop() async {
    await posSub?.cancel();
    posSub = null;
    running = false;
  }
}