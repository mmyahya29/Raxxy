// import 'dart:io';
// import 'package:path_provider/path_provider.dart';
// import 'package:sensors_plus/sensors_plus.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:share_plus/share_plus.dart';
// import 'package:permission_handler/permission_handler.dart';
//
// class TelemetryLogger {
//   File? _file;
//   IOSink? _sink;
//   bool isLogging = false;
//   String? _currentFilePath;
//
//   Future<void> startLogging() async {
//     if (isLogging) return;
//
//     Directory? directory;
//
//     if (Platform.isAndroid) {
//       // 1. REQUEST RUNTIME PERMISSIONS
//       if (await Permission.manageExternalStorage.isDenied) {
//         await Permission.manageExternalStorage.request();
//       }
//       if (await Permission.storage.isDenied) {
//         await Permission.storage.request();
//       }
//
//       // 2. CHECK IF PERMISSION WAS GRANTED
//       if (await Permission.manageExternalStorage.isGranted || await Permission.storage.isGranted) {
//         // Route directly to the public Android Downloads folder
//         directory = Directory('/storage/emulated/0/Download');
//
//         if (!await directory.exists()) {
//           directory = await getExternalStorageDirectory();
//         }
//       } else {
//         // If the user denies permission, fallback to the safe app-sandbox
//         print('⚠️ Storage permission denied. Falling back to app directory.');
//         directory = await getExternalStorageDirectory();
//       }
//     } else {
//       // Fallback for iOS sandbox
//       directory = await getApplicationDocumentsDirectory();
//     }
//
//     final timestamp = DateTime.now().millisecondsSinceEpoch;
//
//     // Named specifically for easy searching in the file manager
//     _currentFilePath = '${directory?.path}/raxxy_telemetry_$timestamp.csv';
//     _file = File(_currentFilePath!);
//
//     // Open file for writing
//     _sink = _file!.openWrite();
//
//     // Write Expanded CSV Header (Supports up to 6 values for GPS)
//     _sink!.writeln('timestamp,sensor_type,val1,val2,val3,val4,val5,val6');
//     isLogging = true;
//     print('🔴 Recording Telemetry to $_currentFilePath');
//   }
//
//   void logAccelerometer(UserAccelerometerEvent event) {
//     if (!isLogging || _sink == null) return;
//     final now = DateTime.now().millisecondsSinceEpoch;
//     // Format: timestamp, accel, x, y, z, empty, empty, empty
//     _sink!.writeln('$now,accel,${event.x},${event.y},${event.z},0,0,0');
//   }
//
//   void logMagnetometer(MagnetometerEvent event) {
//     if (!isLogging || _sink == null) return;
//     final now = DateTime.now().millisecondsSinceEpoch;
//     // Format: timestamp, mag, x, y, z, empty, empty, empty
//     _sink!.writeln('$now,mag,${event.x},${event.y},${event.z},0,0,0');
//   }
//
//   // NEW: Log Gyroscope for EKF Yaw Rate prediction
//   void logGyroscope(GyroscopeEvent event) {
//     if (!isLogging || _sink == null) return;
//     final now = DateTime.now().millisecondsSinceEpoch;
//     // Format: timestamp, gyro, x, y, z, empty, empty, empty
//     _sink!.writeln('$now,gyro,${event.x},${event.y},${event.z},0,0,0');
//   }
//
//   // UPDATED: Log expanded GPS data (Accuracy, Heading, Altitude)
//   void logGps(Position position) {
//     if (!isLogging || _sink == null) return;
//     final now = DateTime.now().millisecondsSinceEpoch;
//     // Format: timestamp, gps, lat, lon, speed, accuracy, heading, altitude
//     _sink!.writeln('$now,gps,${position.latitude},${position.longitude},${position.speed},${position.accuracy},${position.heading},${position.altitude}');
//   }
//
//   Future<void> stopAndExport() async {
//     if (!isLogging || _sink == null) return;
//     isLogging = false;
//
//     await _sink!.flush();
//     await _sink!.close();
//     print('⏹️ Stopped Recording. File saved at: $_currentFilePath');
//
//     // Prompt the OS share dialog to easily email/AirDrop the CSV to your computer
//     if (_currentFilePath != null && await File(_currentFilePath!).exists()) {
//       await Share.shareXFiles([XFile(_currentFilePath!)], text: 'Telemetry Data');
//     }
//   }
// }