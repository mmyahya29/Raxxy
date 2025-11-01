import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class SOSScreen extends StatefulWidget {
  final Position position;
  final double lastSpeed;

  const SOSScreen({super.key, required this.position, required this.lastSpeed});

  @override
  State<SOSScreen> createState() => SOSScreenState();
}

class SOSScreenState extends State<SOSScreen> {
  int countdown = 30;
  bool isCancelled = false;

  @override
  void initState() {
    super.initState();

    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));

      if (!mounted) return false;

      if (isCancelled) return false;
      setState(() {
        countdown = countdown - 1;
      });

      if (countdown == 0) {
        sendEmergencyMessage();
        return false;
      }
      return true;
    });
  }

  void sendEmergencyMessage() {

    print(" Accident Alert ");
    print("Location maybe: ${widget.position.latitude}, ${widget.position.longitude}");
    print("Approx Speed: ${widget.lastSpeed} km/h");
    print("Sending SMS to saved contacts... (not real yet)");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Emergency SOS")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Possible Accident Detected!",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Text("SOS will be sent in $countdown seconds"),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  isCancelled = true;
                });
                Navigator.pop(context);
              },
              child: const Text("I am Safe (Cancel SOS)"),
            ),
          ],
        ),
      ),
    );
  }
}