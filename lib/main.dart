import 'package:alarm/alarm.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app.dart';
import 'core/notifications.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await Alarm.init(showDebugLogs: false);
  try {
    await Notifications.init();
  } catch (_) {
    // Reminders are optional; the alarm and blocking still work without them.
  }
  runApp(const ProviderScope(child: GoodNightApp()));
}
