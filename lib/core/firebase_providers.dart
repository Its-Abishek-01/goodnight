import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authProvider = Provider<FirebaseAuth>((_) => FirebaseAuth.instance);

final firestoreProvider =
    Provider<FirebaseFirestore>((_) => FirebaseFirestore.instance);

/// Signs in anonymously on first launch and reuses the same uid afterwards.
final uidProvider = FutureProvider<String>((ref) async {
  final auth = ref.watch(authProvider);
  final user = auth.currentUser ?? (await auth.signInAnonymously()).user!;
  return user.uid;
});
