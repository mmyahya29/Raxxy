import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_sms/flutter_sms.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/goals_provider.dart';
import '../providers/safety_feature_provider.dart';

class CrashDetector {
  static Timer? countdownTimer;
  static Timer? vibrationTimer1;
  static Timer? vibrationTimer2;
  static int remainingSeconds = 15;
  static final AudioPlayer audioPlayer = AudioPlayer();
  static bool _isActive = false;
  static BuildContext? _dialogContext;

  static Future<void> checkForCrash(
      BuildContext context,
      WidgetRef ref, {
        VoidCallback? onDialogClosed,
      }) async {
    if (_isActive) return;
    _isActive = true;
    remainingSeconds = 15;
    print("CrashDetector: Crash detection initiated");

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

    // Stage 3: Final vibration after 10 seconds
    vibrationTimer2 = Timer(const Duration(seconds: 10), () async {
      if (await Vibration.hasVibrator() ?? false) {
        Vibration.vibrate(duration: 3000);
      }
      // Uncomment to play alert sound:
      // await audioPlayer.play(AssetSource('sounds/alert.mp3'));
    });

    // Start countdown
    _startCountdown(onDialogClosed, ref);

    // Show dialog
    if (context.mounted) {
      _showCrashDialog(context, ref, onDialogClosed: onDialogClosed);
    }
  }

  static void _showCrashDialog(
      BuildContext parentContext,
      WidgetRef ref, {
        VoidCallback? onDialogClosed,
      }) {
    showDialog(
      context: parentContext,
      barrierDismissible: false,
      builder: (dialogContext) {
        _dialogContext = dialogContext;
        return _CrashDialogContent(
          onDismiss: () {
            _cancelCountdown();
            _closeDialog();
            _isActive = false;
            onDialogClosed?.call();
          },
          onSendHelp: () async {
            await _sendHelp(ref);
            onDialogClosed?.call();
          },
        );
      },
    ).then((_) {
      _isActive = false;
      _dialogContext = null;
    });
  }

  static Future<void> _sendHelp(WidgetRef ref) async {
    _cancelCountdown();
    _isActive = false;
    _closeDialog();

    await audioPlayer.stop();
    print("CrashDetector: Sending emergency help");

    // Get emergency contact from preferences
    final prefs = ref.read(sharedPreferencesProvider);
    String? emergencyContact =prefs.getString('emergency_contact');

    // Validate phone number
    if (emergencyContact == null || emergencyContact.isEmpty || emergencyContact == 'null') {
      print("❌ No emergency contact configured");
      return;
    }

    // Ensure proper format: +92XXXXXXXXXX (remove leading 0 if present)
    if (emergencyContact.startsWith("0")) {
      emergencyContact = "+92${emergencyContact.substring(1)}";
    } else if (!emergencyContact.startsWith("+")) {
      emergencyContact = "+92$emergencyContact";
    }

    print("Attempting to send SMS to: $emergencyContact");

    String message =
        "🚨 EMERGENCY: I've been in an accident and need help! This is an automated message from RAXXY.";

    // Try Method 1: flutter_sms (Direct send)
    bool sentDirectly = await _sendViaSMS(emergencyContact, message);

    // If direct send failed, fallback to Method 2: url_launcher (Open SMS app)
    if (!sentDirectly) {
      print("⚠️ Direct SMS failed, opening SMS app as fallback...");
      await _openSMSApp(emergencyContact, message);
    } else {
    }
  }

  /// Method 1: Send SMS directly using flutter_sms
  static Future<bool> _sendViaSMS(String contact, String message) async {
    try {
      String result = await sendSMS(
        message: message,
        recipients: [contact],
        sendDirect: true,
      );

      print("✅ SMS sent directly: $result");
      return true;
    } catch (e) {
      print("❌ Direct SMS failed: $e");
      return false;
    }
  }

  /// Method 2: Fallback - Open default SMS app
  static Future<void> _openSMSApp(String contact, String message) async {
    try {
      final Uri smsUri = Uri(
        scheme: 'sms',
        path: contact,
        queryParameters: {'body': message},
      );

      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
        print("✅ SMS app opened successfully");
      } else {
        print("❌ Cannot launch SMS app");
      }
    } catch (e) {
      print("❌ Failed to open SMS app: $e");
    }
  }

  static void _startCountdown(VoidCallback? onDialogClosed, WidgetRef ref) {
    countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      remainingSeconds--;
      if (remainingSeconds <= 0) {
        timer.cancel();
        print("CrashDetector: Countdown finished — auto-sending help");
        _sendHelp(ref);
        onDialogClosed?.call();
      }
    });
  }

  static void _closeDialog() {
    if (_dialogContext != null &&
        _dialogContext!.mounted &&
        Navigator.of(_dialogContext!).canPop()) {
      Navigator.of(_dialogContext!).pop();
      print("CrashDetector: Dialog closed safely");
    }
  }

  static void _cancelCountdown() {
    countdownTimer?.cancel();
    vibrationTimer1?.cancel();
    vibrationTimer2?.cancel();
    audioPlayer.stop();
    Vibration.cancel();
  }

  static void reset() {
    _cancelCountdown();
    _isActive = false;
    remainingSeconds = 15;
    _dialogContext = null;
  }
}

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
    _uiUpdateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() {});
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