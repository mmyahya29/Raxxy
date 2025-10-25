import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:raxxy/providers/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

final featureNotifierProvider =
StateNotifierProvider<featureNotifier, bool>((ref) => featureNotifier());

class featureNotifier extends StateNotifier<bool> {

  featureNotifier() : super(false) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final featureIndex = prefs.getInt("safety");

    if (featureIndex != null) {
      state = false;
    }
  }

  Future<void> togglefeature() async {
    final prefs = await SharedPreferences.getInstance();

    if (state == false) {
      state = true;
    } else {
      state = false;
    }
    print(state);
    await prefs.setString("safety", state.toString());
  }
}

final emergencyContactProvider = StreamProvider<String?>((ref) {
  final auth = ref.read(firebaseAuthProvider);
  final firestore = ref.read(firestoreProvider);

  final userId = auth.currentUser?.uid;
  if (userId == null) return const Stream.empty();

  return firestore
      .collection('users')
      .doc(userId)
      .snapshots()
      .map((doc) => doc.data()?['emergencyContact'] as String?);
});

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});
