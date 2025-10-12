import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../main.dart';
import 'package:workmanager/workmanager.dart';



class CrashDetector {
  static Future<void> checkForCrash() async {
    print("CrashDetector: Checking for crash...");

    if (navigatorKey.currentContext != null) {
      showCrashDialog();
    } else {
      print("Context not available for dialog");
    }
  }

  static void showCrashDialog() {
    final context = navigatorKey.currentContext!;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(' Possible Crash Detected'),
          content: const Text('Are you safe?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('I\'m Safe'),
            ),
          ],
        );
      },
    );
  }
}
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    await CrashDetector.checkForCrash();
    return Future.value(true);
  });
}
