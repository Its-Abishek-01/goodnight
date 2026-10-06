import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase_providers.dart';
import '../../core/notifications.dart';

/// Registers this phone for push alerts from the partner (needs the optional
/// Cloud Function in /functions to actually send them) and shows pushes that
/// arrive while the app is open.
final pushSyncProvider = Provider<void>((ref) {
  final uid = ref.watch(uidProvider).value;
  if (uid == null) return;
  final db = ref.read(firestoreProvider);
  final messaging = FirebaseMessaging.instance;

  Future<void> save(String? token) async {
    if (token == null) return;
    await db.doc('users/$uid').set({'fcmToken': token}, SetOptions(merge: true));
  }

  messaging
      .requestPermission()
      .then((_) => messaging.getToken())
      .then(save)
      .catchError((_) {});
  final refresh = messaging.onTokenRefresh.listen(save, onError: (_) {});
  final foreground = FirebaseMessaging.onMessage.listen((m) {
    final n = m.notification;
    if (n != null) {
      Notifications.showNow(m.hashCode & 0x7fffffff, n.title ?? 'GoodNight', n.body ?? '');
    }
  });
  ref.onDispose(() {
    refresh.cancel();
    foreground.cancel();
  });
});
