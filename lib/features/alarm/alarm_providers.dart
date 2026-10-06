import 'dart:async';

import 'package:alarm/alarm.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase_providers.dart';
import '../bedtime/schedule_providers.dart';
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

/// Keeps the wake alarm in step with this person's approved wake time.
final alarmSyncProvider = Provider<void>((ref) {
  final uid = ref.watch(uidProvider).value;
  ref.listen(schedulesProvider, (_, next) async {
    final map = next.value;
    if (uid == null || map == null) return;
    final wake = map[uid]?.current?.wake;
    try {
      if (wake == null) {
        await AlarmScheduler.cancelWake();
      } else {
        await AlarmScheduler.scheduleWake(wake);
      }
    } catch (_) {
      // Missing exact-alarm permission is surfaced on the Setup tab.
    }
  }, fireImmediately: true);
});
