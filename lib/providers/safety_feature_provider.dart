import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:raxxy/providers/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

final featureNotifierProvider =
StateNotifierProvider<FeatureNotifier, bool>((ref) => FeatureNotifier());

class FeatureNotifier extends StateNotifier<bool> {
  static const _safetyKey = 'safety';

  FeatureNotifier() : super(false) {
    _loadSafetyFeature();
  }

  /// Loads the persisted safety feature toggle state from SharedPreferences.
  /// Bug fix: was using prefs.getInt() but value was saved as String.
  ///          Also, the loaded value was never applied — always set to false.
  Future<void> _loadSafetyFeature() async {
    final prefs = await SharedPreferences.getInstance();
    final savedValue = prefs.getBool(_safetyKey); // ✅ Use getBool consistently
    if (savedValue != null) {
      state = savedValue; // ✅ Actually restore the saved state
    }
  }

  /// Toggles the safety feature and persists the new state.
  /// Bug fix: was saving with prefs.setString() but reading with prefs.getInt().
  Future<void> toggleFeature() async {
    final prefs = await SharedPreferences.getInstance();
    state = !state; // ✅ Simplified toggle
    debugPrint('Safety feature toggled: $state'); // ✅ Use debugPrint, not print
    await prefs.setBool(_safetyKey, state); // ✅ Use setBool/getBool consistently
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