import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:raxxy/services/driver_profile_service.dart';
import 'package:raxxy/providers/provider.dart';

final driverProfileProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final auth = ref.read(firebaseAuthProvider);
  final userId = auth.currentUser?.uid;

  if (userId == null) {
    return DriverProfileService.getDefaultProfile();
  }

  // Try to get cached profile first
  final cached = await DriverProfileService.getCachedProfile(userId);

  // If cache is recent (within 24 hours), use it
  if (cached != null && cached['lastAnalyzed'] != null) {
    final lastAnalyzed = (cached['lastAnalyzed'] as Timestamp).toDate();
    if (DateTime.now().difference(lastAnalyzed).inHours < 24) {
      return cached;
    }
  }

  // Otherwise, analyze fresh
  final profile = await DriverProfileService.analyzeDriverProfile(userId: userId);

  // Save to cache
  await DriverProfileService.saveProfile(userId: userId, profile: profile);

  return profile;
});