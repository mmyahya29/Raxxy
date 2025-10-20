import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../main.dart';
import 'package:telephony/telephony.dart';
import 'package:vibration/vibration.dart';

class CrashDetector {
  static Timer? countdownTimer;
  static Timer? vibrationTimer1;
  static Timer? vibrationTimer2;
  static int remainingSeconds = 15;
  static final AudioPlayer audioPlayer = AudioPlayer();
  static bool _isActive = false;

  static Future<void> checkForCrash(BuildContext context, {VoidCallback? onDialogClosed}) async {
    // Prevent multiple simultaneous crash detections
    if (_isActive) {
      print("CrashDetector: Already active, ignoring duplicate trigger");
      return;
    }

    _isActive = true;
    print("CrashDetector: Crash detection initiated");

    remainingSeconds = 15;

    // Stage 1: Initial vibration (2 seconds)
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 2000);
    }

    // Stage 2: Second vibration after 5 seconds
    vibrationTimer1 = Timer(const Duration(seconds: 5), () async {
      if (await Vibration.hasVibrator() ?? false) {
        Vibration.vibrate(duration: 3000);
      }
    });

    // Stage 3: Final vibration + sound after 10 seconds
    vibrationTimer2 = Timer(const Duration(seconds: 10), () async {
      if (await Vibration.hasVibrator() ?? false) {
        Vibration.vibrate(duration: 3000);
      }
      // Uncomment to play alert sound
      // await audioPlayer.play(AssetSource('sounds/alert.mp3'));
    });

    // Start countdown
    _startCountdown(context);

    // Show dialog (non-blocking)
    if (context.mounted) {
      _showCrashDialog(context, onDialogClosed: onDialogClosed);
    }
  }

  static void _showCrashDialog(BuildContext context, {VoidCallback? onDialogClosed}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _CrashDialogContent(
          onDismiss: () {
            _cancelCountdown();
            _isActive = false;
            if (dialogContext.mounted) {
              Navigator.of(dialogContext).pop();
            }
            // Reset crash detection flag in monitoring service
            onDialogClosed?.call();
          },
          onSendHelp: () {
            _sendHelp(dialogContext);
            // Reset crash detection flag in monitoring service
            onDialogClosed?.call();
          },
        );
      },
    ).then((_) {
      // Ensure cleanup when dialog is dismissed
      _isActive = false;
      onDialogClosed?.call();
    });
  }

  static void _sendHelp(BuildContext context) async {
    _cancelCountdown();
    _isActive = false;

    if (context.mounted) {
      Navigator.of(context).pop();
    }

    await audioPlayer.stop();

    print("CrashDetector: Sending emergency help");

    String emergencyContact = "+923091163059"; // Replace with user's emergency contact

    if (emergencyContact.isNotEmpty) {
      if (smsPermissionGranted) {
        try {
          await telephony.sendSms(
            to: emergencyContact,
            message: "🚨 EMERGENCY: I've been in an accident and need help! This is an automated message from RAXXY.",
          );
          print("Emergency SMS sent to $emergencyContact");
        } catch (e) {
          print("Failed to send SMS: $e");
        }
      } else {
        print("SMS Permission not granted");
      }
    } else {
      print("No emergency contact configured");
    }
  }

  static void _startCountdown(BuildContext context) {
    countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      remainingSeconds--;

      if (remainingSeconds <= 0) {
        timer.cancel();
        _sendHelp(context);
      }
    });
  }

  static void _cancelCountdown() {
    countdownTimer?.cancel();
    vibrationTimer1?.cancel();
    vibrationTimer2?.cancel();
    audioPlayer.stop();
    Vibration.cancel();

    print("CrashDetector: Countdown cancelled");
  }

  // Reset method for testing or manual cleanup
  static void reset() {
    _cancelCountdown();
    _isActive = false;
    remainingSeconds = 15;
  }
}

// Separate StatefulWidget for dialog to handle countdown updates
class _CrashDialogContent extends StatefulWidget {
  final VoidCallback onDismiss;
  final VoidCallback onSendHelp;

  const _CrashDialogContent({
    required this.onDismiss,
    required this.onSendHelp,
  });

  @override
  State<_CrashDialogContent> createState() => _CrashDialogContentState();
}

class _CrashDialogContentState extends State<_CrashDialogContent> {
  late Timer _uiUpdateTimer;

  @override
  void initState() {
    super.initState();
    // Update UI every second to show countdown
    _uiUpdateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {});
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _uiUpdateTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.red, size: 32),
          SizedBox(width: 12),
          Text("Crash Detected!"),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Are you okay? Do you need help?",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.timer, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Auto-sending help in ${CrashDetector.remainingSeconds} seconds",
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: widget.onDismiss,
          child: const Text("I'm Fine"),
        ),
        ElevatedButton(
          onPressed: widget.onSendHelp,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: const Text("Send Help Now"),
        ),
      ],
    );
  }
}