import 'package:flutter/material.dart';
import 'package:flutter_sms/flutter_sms.dart';

class GuardianAlertScreen extends StatefulWidget {
  final String driverName;
  final String distance;
  final String maxSpeed;
  final int harshBrakes;
  final int harshAccelerations;
  final String guardianContact;

  const GuardianAlertScreen({
    Key? key,
    required this.driverName,
    required this.distance,
    required this.maxSpeed,
    required this.harshBrakes,
    required this.harshAccelerations,
    required this.guardianContact,
  }) : super(key: key);

  @override
  State<GuardianAlertScreen> createState() => _GuardianAlertScreenState();
}

class _GuardianAlertScreenState extends State<GuardianAlertScreen> {
  String _statusMessage = "Sending trip summary to guardian...";
  bool _isSending = true;

  @override
  void initState() {
    super.initState();
    // Start sending the SMS as soon as the screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sendGuardianSms();
    });
  }

  Future<void> _sendGuardianSms() async {
    String smsMessage = "🛡️ RAXXY Guardian Alert:\n"
        "${widget.driverName} has finished driving.\n"
        "• Distance: ${widget.distance} km\n"
        "• Max Speed: ${widget.maxSpeed} km/h\n"
        "• Harsh Brakes: ${widget.harshBrakes}\n"
        "• Harsh Accels: ${widget.harshAccelerations}";

    try {
      await sendSMS(
        message: smsMessage,
        recipients: [widget.guardianContact],
        sendDirect: true, // Sends in background if supported
      );
      if (mounted) {
        setState(() {
          _statusMessage = "Guardian Summary SMS sent successfully!";
          _isSending = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = "Failed to send SMS to ${widget.guardianContact}.";
          _isSending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSending, // Prevent backing out while sending
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Guardian Alert'),
          automaticallyImplyLeading: !_isSending,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _isSending ? Icons.sms : (_statusMessage.contains("Failed") ? Icons.error_outline : Icons.check_circle_outline),
                  size: 80,
                  color: _isSending ? Colors.blue : (_statusMessage.contains("Failed") ? Colors.red : Colors.green),
                ),
                const SizedBox(height: 24),
                Text(
                  _statusMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 32),
                if (!_isSending)
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Done'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}