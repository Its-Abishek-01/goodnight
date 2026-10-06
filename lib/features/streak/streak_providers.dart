import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../bedtime/schedule_providers.dart';
import '../checkin/night_log.dart';
import '../checkin/night_providers.dart';
import '../pairing/pair_providers.dart';
import 'streak.dart';

/// The pair's approved windows, keyed by uid.
final windowsProvider = Provider((ref) {
  final schedules = ref.watch(schedulesProvider).value ?? const {};
  return {
    for (final e in schedules.entries)
      if (e.value.current != null) e.key: e.value.current!,
  };
});

/// The current shared streak.
final streakProvider = Provider<StreakInfo>((ref) {
  final pair = ref.watch(pairProvider).value;
  if (pair == null) return StreakInfo.none;
  return computeStreak(
    ref.watch(nightsProvider).value ?? const [],
    ref.watch(windowsProvider),
    pair.members,
    nightKey(DateTime.now()),
  );
});
