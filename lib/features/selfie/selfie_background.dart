import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../../core/notifications.dart';
import 'selfie.dart';
import 'selfie_widget.dart';

/// Runs when a data push arrives while the app is closed. It fetches the new
/// selfie, refreshes the home-screen widget and shows a notification.
@pragma('vm:entry-point')
Future<void> goodnightBackgroundHandler(RemoteMessage message) async {
  if (message.data['type'] != 'selfie') return;
  try {
    await Firebase.initializeApp();
    final doc = await FirebaseFirestore.instance
        .doc('pairs/${message.data['pairId']}/selfies/${message.data['selfieId']}')
        .get();
    if (!doc.exists) return;
    final selfie = Selfie.fromDoc(doc);
    final name = (message.data['name'] as String?) ?? 'Your partner';
    await SelfieHomeWidget.update(
      bytes: selfie.bytes,
      caption: captionFor(name, selfie.createdAt),
    );
    await Notifications.init();
    await Notifications.showNow(
      3001,
      '📸 $name sent you a selfie',
      'Open GoodNight to see it.',
    );
  } catch (_) {
    // Nothing useful to do from a background isolate.
  }
}
