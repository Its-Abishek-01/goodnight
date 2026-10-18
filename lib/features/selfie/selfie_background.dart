import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:home_widget/home_widget.dart';

import '../../core/notifications.dart';
import '../sleep_widget/sleep_widget.dart';
import '../sleep_widget/sleep_widget_content.dart';
import 'selfie.dart';
import 'selfie_widget.dart';

/// Runs when a data push arrives while the app is closed: a new selfie, or
/// the partner checking in or waking up (for the "Going to sleep" widget).
@pragma('vm:entry-point')
Future<void> goodnightBackgroundHandler(RemoteMessage message) async {
  switch (message.data['type']) {
    case 'selfie':
      await _selfie(message);
    case 'status':
      await _status(message);
  }
}

/// The partner checked in or woke up: update the widget, and say when they
/// are going to sleep. Uses the name the widget already shows (your pet name
/// for them, if you set one).
Future<void> _status(RemoteMessage message) async {
  try {
    final at = DateTime.tryParse(message.data['at'] as String? ?? '')?.toLocal() ?? DateTime.now();
    final state = message.data['state'] as String? ?? '';
    final name = await HomeWidget.getWidgetData<String>('sleep_partner_name') ??
        (message.data['name'] as String?) ??
        'Your partner';
    await SleepHomeWidget.savePartnerLine(partnerStatusLine(name, state, at));
    if (state == 'asleep') {
      await Notifications.init();
      await Notifications.showNow(3002, '🌙 $name is going to sleep', 'Goodnight! Phone down soon?');
    }
  } catch (_) {}
}

Future<void> _selfie(RemoteMessage message) async {
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
