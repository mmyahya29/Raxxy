import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../main.dart';
import 'package:workmanager/workmanager.dart';
import 'package:telephony/telephony.dart';
import 'package:vibration/vibration.dart';


//If u remember...
//what I had in mind was k jb crash detect ho tw instantly dialog box show how or ik level of alert ho
//then 5 sec baad ik or alert, 10 k baad ik or alert, 15 k baad jo b mamlaat in case of emergency krny thy
// nichy apny hisaab sy kuch kiya hai....it should not be difficult but I commented about everything
//feel free to change anything if u think otherwise




final Telephony telephony = Telephony.instance;
bool smsPermissionGranted = false;

class CrashDetector {
  static Timer? countdownTimer;
  static int remainingSeconds = 15;
  static final AudioPlayer audioPlayer = AudioPlayer();

  static Future<void> checkForCrash(BuildContext context) async {
    print("CrashDetector: Checking for crash...");

    remainingSeconds = 15;

    // 1st Stage check // 2 seconds ki vibration at the moment of possible detection
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 2000);
    }

    // Next vibration + sound(Dekh lo if sound lgana hai ya ni...if lgana hai tw simple assets mein add kr dyna) ka timer
    Timer(const Duration(seconds: 5), () async {
      if (await Vibration.hasVibrator() ?? false) {
        Vibration.vibrate(duration: 3000);
      }
    });

    // final stage // isky 5 second baad timer end ho jaega
    Timer(const Duration(seconds: 10), () async {
      if (await Vibration.hasVibrator() ?? false) {
        Vibration.vibrate(duration: 3000);
      }
      // Play alert sound // yahan pr path dy dena, //I'm commenting this line for now
      // _audioPlayer.play(AssetSource('sounds/alert.mp3'));
    });

    // Start countdown
    startCountdown(context);

    // Show dialog
    showCrashDialog(context);
  }

  static void showCrashDialog(BuildContext context) {
    showDialog(
      context: context,
      // means out of the box tap krny sy bnd ni hoga...
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Crash Detected!"),
              content: Text(
                "Do you need help?\n\nAutomatically sending help in $remainingSeconds seconds...",
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    cancelCountdown();
                    Navigator.of(context).pop(); // Dismiss dialog
                  },
                  child: const Text("No I'm fine"),
                ),
                ElevatedButton(
                  onPressed: () {
                    sendHelp(context);
                  },
                  child: const Text("Send Help"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  static void sendHelp(BuildContext context)async{
    cancelCountdown();
    Navigator.of(context).pop();
    audioPlayer.stop();

    // this is the empty function idr baqi kaam krny hen like kya kya bhjna kese kese bhjna...

    if (smsPermissionGranted) {
      await telephony.sendSms(
        to: "+923091163059",
        message: "I need help",
      );
      print("Emergency SMS sent");
    } else {
      print("SMS Permission not granted");
    }

  }


  static void startCountdown(BuildContext context) {
    countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      remainingSeconds--;
      if (remainingSeconds <= 0) {
        timer.cancel();
        sendHelp(context);
      }
    });
  }

  static void cancelCountdown() {
    countdownTimer?.cancel();
  }
}
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    //isko comment kiya hai cuz at the moment Im not sure how this is gonna work
    // await CrashDetector.checkForCrash();
    return Future.value(true);
  });
}
