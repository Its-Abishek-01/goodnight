import 'dart:async';

import 'package:alarm/alarm.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase_providers.dart';
import '../bedtime/schedule_providers.dart';
import '../settings/features_providers.dart';
import 'alarm_scheduler.dart';

/// The id of the alarm that is ringing right now, or null.
class RingNotifier extends Notifier<int?> {
  StreamSubscription<AlarmSettings>? _sub;

  @override
  int? build() {
    _sub = Alarm.ringStream.stream.listen((s) => state = s.id);
    ref.onDispose(() => _sub?.cancel());
    _checkAlreadyRinging();
    return null;
  }

  Future<void> _checkAlreadyRinging() async {
    for (final a in await Alarm.getAlarms()) {
      if (await Alarm.isRinging(a.id)) {
        state = a.id;
        return;
      }
    }
  }

  void clear() => state = null;
}

final ringProvider = NotifierProvider<RingNotifier, int?>(RingNotifier.new);

/// Keeps the wake alarm in step with this person's approved wake time, or
/// switched off when they do not use the alarm.
final alarmSyncProvider = Provider<void>((ref) {
  final uid = ref.watch(uidProvider).value;
  Future<void> sync() async {
    final map = ref.read(schedulesProvider).value;
    final features = ref.read(myFeaturesProvider);
    if (uid == null || map == null || features == null) return;
    final wake = map[uid]?.current?.wake;
    try {
      if (!features.alarm) {
        await AlarmScheduler.stopAll();
      } else if (wake == null) {
        await AlarmScheduler.cancelWake();
      } else {
        await AlarmScheduler.scheduleWake(wake);
      }
    } catch (_) {
      // Missing exact-alarm permission is surfaced on the Setup tab.
    }
  }

  ref.listen(schedulesProvider, (_, _) => sync(), fireImmediately: true);
  ref.listen(myFeaturesProvider, (_, _) => sync());
});
