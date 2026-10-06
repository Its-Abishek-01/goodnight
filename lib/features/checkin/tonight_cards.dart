import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../pairing/pair.dart';
import '../streak/streak_providers.dart';
import 'night_log.dart';
import 'night_providers.dart';

String _time(BuildContext context, DateTime t) =>
    TimeOfDay.fromDateTime(t).format(context);

/// Shared streak banner.
class StreakCard extends ConsumerWidget {
  const StreakCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(streakProvider);
    return Card(
      child: ListTile(
        leading: const Text('🔥', style: TextStyle(fontSize: 28)),
        title: Text(s.count == 0 ? 'No streak yet' : '${s.count}-night streak'),
        subtitle: const Text(
          'Both of you on time and up properly keeps it going. 7, 14, 30 and 60 nights earn a coupon.',
        ),
      ),
    );
  }
}

/// "Going to sleep" check-in, open from 2 hours before bedtime.
class CheckInCard extends ConsumerWidget {
  const CheckInCard({super.key, required this.pair, required this.uid});

  final Pair pair;
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final window = ref.watch(windowsProvider)[uid];
    if (window == null) return const SizedBox.shrink();
    final now = DateTime.now();
    final nights = ref.watch(nightsProvider).value ?? const [];
    final key = nightKey(now);
    final mine = nights.where((n) => n.key == key).firstOrNull?.playerOf(uid);

    final delta = (((now.hour * 60 + now.minute) - window.bedtime + 720) % 1440) - 720;
    final open = delta >= -120 && delta <= 240;

    Widget child;
    if (mine?.checkedInAt != null) {
      child = Text('✅ Checked in at ${_time(context, mine!.checkedInAt!)}');
    } else if (open) {
      child = FilledButton.icon(
        onPressed: () => ref
            .read(nightLogRepositoryProvider)
            .checkIn(pair.id, uid, DateTime.now()),
        icon: const Icon(Icons.bedtime),
        label: const Text('Going to sleep'),
      );
    } else {
      child = const Text('Check-in opens 2 hours before your bedtime.');
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(width: double.infinity, child: child),
      ),
    );
  }
}

/// How both of you are doing tonight, plus a nudge when the partner is
/// snoozing a lot.
class StatusCard extends ConsumerWidget {
  const StatusCard({super.key, required this.pair, required this.uid});

  final Pair pair;
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nights = ref.watch(nightsProvider).value ?? const [];
    final tonight = nights.where((n) => n.key == nightKey(DateTime.now())).firstOrNull;
    final partnerUid = pair.partnerUid(uid) ?? '';
    final partner = tonight?.playerOf(partnerUid) ?? const PlayerNight();
    final partnerName = pair.nameOf(partnerUid);

    String line(String name, PlayerNight p) {
      if (p.wokeAt != null) return '$name: ☀️ up at ${_time(context, p.wokeAt!)}';
      if (p.checkedInAt != null) {
        return '$name: 😴 asleep since ${_time(context, p.checkedInAt!)}'
            '${p.snoozes > 0 ? ' · snoozed ${p.snoozes}×' : ''}';
      }
      return '$name: ⏳ not checked in yet';
    }

    final struggling = partner.wokeAt == null && partner.snoozes >= 2;
    return Card(
      color: struggling ? Theme.of(context).colorScheme.errorContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(line('You', tonight?.playerOf(uid) ?? const PlayerNight())),
            const SizedBox(height: 6),
            Text(line(partnerName, partner)),
            if (struggling) ...[
              const SizedBox(height: 10),
              Text('$partnerName has snoozed ${partner.snoozes} times. Maybe give them a call 📞'),
            ],
          ],
        ),
      ),
    );
  }
}
