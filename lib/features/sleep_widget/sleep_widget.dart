import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import '../../core/firebase_providers.dart';
import '../bedtime/schedule_providers.dart';
import '../checkin/night_log.dart';
import '../checkin/night_providers.dart';
import '../pairing/pair_providers.dart';
import '../profile/profile.dart';
import '../settings/features.dart';
import '../settings/features_providers.dart';
import '../streak/streak_providers.dart';
import 'sleep_widget_content.dart';

/// The "Going to sleep" home-screen widget (`SleepWidgetProvider` natively):
/// both of you and a button that checks you in.
class SleepHomeWidget {
  static const _androidName = 'SleepWidgetProvider';

  /// The URI the widget's button opens the app with.
  static const checkInUri = 'goodnight://checkin';

  static Future<void> save({
    required SleepWidgetContent content,
    required Person? me,
    required Person? partner,
  }) async {
    await HomeWidget.saveWidgetData<String>('sleep_me', content.meLine);
    await HomeWidget.saveWidgetData<String>('sleep_partner', content.partnerLine);
    await HomeWidget.saveWidgetData<String>('sleep_button', content.buttonLabel);
    await HomeWidget.saveWidgetData<bool>('sleep_can', content.canCheckIn);
    await HomeWidget.saveWidgetData<String>('sleep_partner_name', partner?.name);
    await _person('me', me);
    await _person('partner', partner);
    await HomeWidget.updateWidget(androidName: _androidName);
  }

  static Future<void> _person(String key, Person? p) async {
    final name = p?.name.trim() ?? '';
    await HomeWidget.saveWidgetData<String>(
      'sleep_${key}_initial',
      name.isEmpty ? '?' : name.characters.first.toUpperCase(),
    );
    if (p != null) {
      // Signed 32-bit, so Android reads them back as an Int (not a Long).
      await HomeWidget.saveWidgetData<int>('sleep_${key}_color', p.color.color.toARGB32().toSigned(32));
      await HomeWidget.saveWidgetData<int>('sleep_${key}_on', p.color.onColor.toARGB32().toSigned(32));
    }
  }

  /// After a status push while the app is closed: only the partner line changes.
  static Future<void> savePartnerLine(String line) async {
    await HomeWidget.saveWidgetData<String>('sleep_partner', line);
    await HomeWidget.updateWidget(androidName: _androidName);
  }

  static Future<void> clear() async {
    for (final k in ['me', 'partner', 'button', 'can', 'me_initial', 'partner_initial']) {
      await HomeWidget.saveWidgetData<String>('sleep_$k', null);
    }
    await HomeWidget.updateWidget(androidName: _androidName);
  }
}

/// Keeps the widget in step with tonight's night log and both bedtimes.
final sleepWidgetSyncProvider = Provider<void>((ref) {
  Future<void> sync() async {
    final pair = ref.read(pairProvider).value;
    final uid = ref.read(uidProvider).value;
    if (pair == null || uid == null) return;
    final partnerUid = pair.partnerUid(uid) ?? '';
    final people = ref.read(peopleProvider);
    final windows = ref.read(windowsProvider);
    final nights = ref.read(nightsProvider).value ?? const <Night>[];
    final now = DateTime.now();
    final tonight = nights.where((n) => n.key == nightKey(now)).firstOrNull;
    final content = sleepWidgetContent(
      partnerName: people[partnerUid]?.name ?? pair.nameOf(partnerUid),
      me: tonight?.playerOf(uid) ?? const PlayerNight(),
      partner: tonight?.playerOf(partnerUid) ?? const PlayerNight(),
      myWindow: windows[uid],
      partnerWindow: windows[partnerUid],
      now: now,
    );
    try {
      await SleepHomeWidget.save(content: content, me: people[uid], partner: people[partnerUid]);
    } catch (_) {
      // No home-screen widget support (tests).
    }
  }

  ref.listen(nightsProvider, (_, _) => sync());
  ref.listen(windowsProvider, (_, _) => sync());
  ref.listen(peopleProvider, (_, _) => sync(), fireImmediately: true);
});

/// The widget button opened the app: check in, if it is time and you have
/// not already. Returns a line to show, or null when nothing happened.
Future<String?> checkInFromWidget(WidgetRef ref) async {
  final pair = ref.read(pairProvider).value;
  final uid = ref.read(uidProvider).value;
  if (pair == null || uid == null) return null;
  // Opened cold from the widget: wait for tonight's log and the bedtimes.
  List<Night> nights;
  try {
    await ref.read(schedulesProvider.future).timeout(const Duration(seconds: 10));
    nights = await ref.read(nightsProvider.future).timeout(const Duration(seconds: 10));
  } catch (_) {
    return "Couldn't check in. Check your connection and try again.";
  }
  final window = ref.read(windowsProvider)[uid];
  if (window == null) return 'Set your bedtime first.';
  final now = DateTime.now();
  final mine = nights.where((n) => n.key == nightKey(now)).firstOrNull?.playerOf(uid);
  if (mine?.checkedInAt != null) return 'Already checked in. Sleep well 🌙';
  if (!checkInOpenAt(window, now)) return 'Check-in opens 2 hours before your bedtime.';
  await ref.read(nightLogRepositoryProvider).checkIn(
        pair.id,
        uid,
        now,
        alarm: (ref.read(myFeaturesProvider) ?? PersonalFeatures.all).alarm,
      );
  return 'Checked in. Phone down, sleep well 🌙';
}
