import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:raxxy/providers/vehicle_data.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final authStateProvider = StreamProvider<User?>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  return auth.authStateChanges();
});

// final googleSignInProvider = Provider<GoogleSignIn>((ref) {
//   return GoogleSignIn();
// });

final firestoreProvider = Provider((ref) => FirebaseFirestore.instance);


class VehicleMonitorNotifier extends StateNotifier<VehicleMonitorState> {
  VehicleMonitorNotifier() : super(VehicleMonitorState());

  void setVehicle(String? id) {
    state = state.copyWith(vehicleId: id);
  }

  void setMake(String? make) {
    state = state.copyWith(make: make);
  }

  void setModel(String? model) {
    state = state.copyWith(model: model);
  }

  void updateSpeed(double speed) {
    state = state.copyWith(speed: speed);
  }

  void updateAcceleration(double acceleration) {
    state = state.copyWith(acceleration: acceleration);
  }

  void updateDistance(double distance) {
    state = state.copyWith(distance: distance);
  }

  void clear() {
    state = VehicleMonitorState();
  }
}

final vehicleMonitorProvider = StateNotifierProvider<VehicleMonitorNotifier, VehicleMonitorState>(
      (ref) => VehicleMonitorNotifier(),
);
