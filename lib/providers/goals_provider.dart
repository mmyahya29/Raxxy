import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:raxxy/providers/provider.dart';

final goalProvider = StreamProvider.autoDispose((ref) {
  final firestore = ref.read(firestoreProvider);
  final auth = ref.read(firebaseAuthProvider);

  return firestore
      .collection('users')
      .doc(auth.currentUser?.uid)
      .collection('goals')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs);
});

final driveScoreProvider = StreamProvider.autoDispose<double?>((ref) {
  final firestore = ref.read(firestoreProvider);
  final auth = ref.read(firebaseAuthProvider);

  final userId = auth.currentUser?.uid;
  if (userId == null) return const Stream.empty();

  return firestore
      .collection('users')
      .doc(userId)
      .snapshots()
      .map((snapshot) {
    if (!snapshot.exists) return null;
    final data = snapshot.data();
    return (data?['drivingScore'] ?? 50).toDouble(); // default 50
  });
});

