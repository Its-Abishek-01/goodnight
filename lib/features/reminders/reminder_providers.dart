import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notifications.dart';
import '../../core/firebase_providers.dart';
import '../bedtime/schedule_providers.dart';

const wrapUpReminderId = 2001;
const bedtimeReminderId = 2002;

/// Daily reminders: a call wrap-up nudge 30 minutes before bedtime, then a
/// gentle "time to sleep" at bedtime. Follows the approved bedtime.
final reminderSyncProvider = Provider<void>((ref) {
  final uid = ref.watch(uidProvider).value;
  ref.listen(schedulesProvider, (_, next) async {
    final map = next.value;
    if (uid == null || map == null) return;
    final w = map[uid]?.current;
    try {
      if (w == null) {
        await Notifications.cancel(wrapUpReminderId);
        await Notifications.cancel(bedtimeReminderId);
        return;
      }
      await Notifications.scheduleDaily(
        id: wrapUpReminderId,
        minuteOfDay: (w.bedtime - 30) % 1440,
        title: 'Time to wrap up the call 📞',
        body: 'Bedtime is in 30 minutes. Say your goodnights soon.',
      );
      await Notifications.scheduleDaily(
        id: bedtimeReminderId,
        minuteOfDay: w.bedtime,
        title: 'Time to sleep 🌙',
        body: "Tap 'Going to sleep' in GoodNight and put the phone down.",
      );
    } catch (_) {
      // Notification setup is best effort.
    }
  }, fireImmediately: true);
});
