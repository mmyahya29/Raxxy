import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:raxxy/providers/provider.dart';

final summaryProvider = StreamProvider.autoDispose((ref) {
  final firestore = ref.read(firestoreProvider);
  final auth = ref.read(firebaseAuthProvider);

  return firestore
      .collection('users')
      .doc(auth.currentUser?.uid)
      .collection('sessions')
      .orderBy('endTime', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs);
});
