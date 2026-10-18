import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase_providers.dart';
import '../bedtime/schedule_providers.dart';
import '../checkin/night_providers.dart';
import '../pairing/pair_providers.dart';
import '../settings/features_providers.dart';
import 'blocker_channel.dart';

/// Pushes this person's approved bedtime to the native blocker, or turns it
/// off when they do not use night mode.
final blockerSyncProvider = Provider<void>((ref) {
  final uid = ref.watch(uidProvider).value;
  Future<void> sync() async {
    final map = ref.read(schedulesProvider).value;
    final features = ref.read(myFeaturesProvider);
    final pair = ref.read(pairProvider).value;
    if (uid == null || map == null || features == null) return;
    final w = map[uid]?.current;
    try {
      await Blocker.saveConfig(
        enabled: w != null && features.nightMode,
        bedtimeMin: w?.bedtime ?? 0,
        wakeMin: w?.wake ?? 0,
        pairId: pair?.id,
        uid: uid,
      );
    } catch (_) {
      // Not running on Android (tests); nothing to sync.
    }
  }

  ref.listen(schedulesProvider, (_, _) => sync(), fireImmediately: true);
  ref.listen(myFeaturesProvider, (_, _) => sync());
  ref.listen(pairProvider, (_, _) => sync());
});

/// Uploads the native block counts to the shared night log.
Future<void> syncBlockStats(WidgetRef ref) async {
  final pair = ref.read(pairProvider).value;
  final uid = ref.read(uidProvider).value;
  if (pair == null || uid == null) return;
  try {
    final s = await Blocker.getStats();
    if (s == null) return;
    final repo = ref.read(nightLogRepositoryProvider);
    if (s.nightKey.isNotEmpty && (s.blocks > 0 || s.usageMinutes > 0 || s.phoneMinutes > 0)) {
      await repo.recordBlocks(pair.id, uid, s.nightKey,
          blocks: s.blocks, usageMinutes: s.usageMinutes, phoneMinutes: s.phoneMinutes);
    }
    if (s.prevKey.isNotEmpty) {
      await repo.recordBlocks(pair.id, uid, s.prevKey,
          blocks: s.prevBlocks, usageMinutes: s.prevUsageMinutes, phoneMinutes: s.prevPhoneMinutes);
    }
  } catch (_) {
    // Best effort; retried next time the app opens.
  }
}
