import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../bedtime/schedule.dart';
import '../pairing/pair.dart';
import '../profile/person_avatar.dart';
import '../profile/profile.dart';
import '../settings/features.dart';
import '../settings/features_providers.dart';
import '../sleep_widget/sleep_widget_content.dart';
import '../streak/streak.dart';
import '../streak/streak_providers.dart';
import 'moon_journey.dart';
import 'night_log.dart';
import 'night_providers.dart';

String _time(BuildContext context, DateTime t) =>
    TimeOfDay.fromDateTime(t).format(context);

PlayerNight _tonight(WidgetRef ref, String uid) {
  final nights = ref.watch(nightsProvider).value ?? const [];
  final night = nights.where((n) => n.key == nightKey(DateTime.now())).firstOrNull;
  return night?.playerOf(uid) ?? const PlayerNight();
}

/// Shared streak as a small chip. Tap it for the rules.
class StreakChip extends ConsumerWidget {
  const StreakChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(streakProvider);
    return ActionChip(
      avatar: const Icon(Icons.local_fire_department, color: Color(0xFFFFA45C), size: 18),
      label: Text(s.count == 0 ? 'No streak yet' : '${s.count} nights'),
      backgroundColor: context.sky.surface,
      side: BorderSide(color: context.sky.outline),
      shape: const StadiumBorder(),
      onPressed: () => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.local_fire_department, color: Color(0xFFFFA45C), size: 36),
          title: Text(s.count == 0 ? 'Start your streak' : '${s.count}-night streak'),
          content: Text(
            'A night counts when you both check in on time and get up with at most '
            '$maxGoodSnoozes snoozes. ${milestones.join(', ')} nights in a row earn each of you a coupon.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Got it')),
          ],
        ),
      ),
    );
  }
}

/// Tonight's moon journey for the two of you.
class TonightJourney extends ConsumerWidget {
  const TonightJourney({super.key, required this.pair, required this.uid});

  final Pair pair;
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partnerUid = pair.partnerUid(uid) ?? '';
    final people = ref.watch(peopleProvider);
    return MoonJourney(
      me: _tonight(ref, uid),
      partner: _tonight(ref, partnerUid),
      myName: people[uid]?.name ?? pair.nameOf(uid),
      partnerName: people[partnerUid]?.name ?? pair.nameOf(partnerUid),
      myColor: pair.colorOf(uid),
      partnerColor: pair.colorOf(partnerUid),
      myPhoto: people[uid]?.photo,
      partnerPhoto: people[partnerUid]?.photo,
    );
  }
}

/// A gentle nudge when the partner keeps snoozing.
class SnoozeNudge extends ConsumerWidget {
  const SnoozeNudge({super.key, required this.pair, required this.uid});

  final Pair pair;
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partnerUid = pair.partnerUid(uid) ?? '';
    final p = _tonight(ref, partnerUid);
    if (p.wokeAt != null || p.snoozes < 2) return const SizedBox.shrink();
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: ListTile(
        leading: Icon(Icons.phone_in_talk, color: context.sky.accent),
        title: Text('${ref.watch(peopleProvider)[partnerUid]?.name ?? pair.nameOf(partnerUid)} has snoozed ${p.snoozes} times'),
        subtitle: const Text('Maybe give them a call.'),
      ),
    );
  }
}

String _minutesLabel(BuildContext context, int minutes) =>
    TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60).format(context);

/// How your partner's night is going, right now. The two of you share these
/// numbers by design: they see the very same card about you.
class PartnerTonight extends ConsumerWidget {
  const PartnerTonight({super.key, required this.pair, required this.uid});

  final Pair pair;
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partnerUid = pair.partnerUid(uid) ?? '';
    if (partnerUid.isEmpty) return const SizedBox.shrink();
    final p = _tonight(ref, partnerUid);
    final window = ref.watch(windowsProvider)[partnerUid];
    final name = ref.watch(peopleProvider)[partnerUid]?.name ?? pair.nameOf(partnerUid);
    final status = _partnerStatus(context, name, p, window);

    final extras = <String>[
      if (p.usageMinutes > 0) '${p.usageMinutes} min on Instagram/Shorts tonight',
      if (p.blocks > 0) 'Night mode stepped in ${p.blocks}×',
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.sky.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.sky.outline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PersonAvatar(uid: partnerUid, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(status.icon, size: 18, color: context.sky.accent),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(status.headline, style: Theme.of(context).textTheme.titleSmall),
                    ),
                  ],
                ),
                if (status.detail != null) ...[
                  const SizedBox(height: 2),
                  Text(status.detail!, style: Theme.of(context).textTheme.bodySmall),
                ],
                for (final e in extras) ...[
                  const SizedBox(height: 2),
                  Text(e, style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

({IconData icon, String headline, String? detail}) _partnerStatus(
  BuildContext context,
  String name,
  PlayerNight p,
  SleepWindow? w,
) {
  if (p.wokeAt != null) {
    return (
      icon: Icons.wb_sunny_outlined,
      headline: '$name is up',
      detail: 'Awake since ${_time(context, p.wokeAt!)}.',
    );
  }
  if (p.checkedInAt != null) {
    if (p.alarm && p.snoozes > 0) {
      return (
        icon: Icons.snooze,
        headline: '$name is snoozing',
        detail: '${p.snoozes} snooze${p.snoozes == 1 ? '' : 's'} so far this morning.',
      );
    }
    return (
      icon: Icons.bedtime,
      headline: '$name is asleep',
      detail: 'Checked in at ${_time(context, p.checkedInAt!)}.',
    );
  }
  if (w == null) {
    return (icon: Icons.schedule, headline: '$name hasn\'t set a bedtime yet', detail: null);
  }
  final now = DateTime.now();
  final delta = (((now.hour * 60 + now.minute) - w.bedtime + 720) % 1440) - 720;
  final bed = _minutesLabel(context, w.bedtime);
  if (delta > checkInGraceMinutes) {
    return (
      icon: Icons.nightlight_outlined,
      headline: '$name is still up',
      detail: 'Bedtime was $bed — not checked in yet.',
    );
  }
  if (delta >= -120) {
    return (
      icon: Icons.nights_stay_outlined,
      headline: '$name is winding down',
      detail: 'Bedtime $bed. Not checked in yet.',
    );
  }
  return (
    icon: Icons.schedule,
    headline: '$name sleeps at $bed',
    detail: 'Their night hasn\'t started.',
  );
}

/// The big "Going to sleep" button, open from 2 hours before bedtime.
class CheckInButton extends ConsumerWidget {
  const CheckInButton({super.key, required this.pair, required this.uid});

  final Pair pair;
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final window = ref.watch(windowsProvider)[uid];
    if (window == null) {
      return const _Hint(
        icon: Icons.schedule,
        text: 'Set your bedtime below. Your partner approves it, then the journey begins.',
      );
    }
    final mine = _tonight(ref, uid);
    if (mine.wokeAt != null) {
      return _Hint(
        icon: Icons.wb_sunny_outlined,
        text: 'Up at ${_time(context, mine.wokeAt!)}. Have a lovely day.',
      );
    }
    if (mine.checkedInAt != null) {
      return _Hint(
        icon: Icons.check_circle,
        text: 'Checked in at ${_time(context, mine.checkedInAt!)}. Phone down, sleep well.',
      );
    }
    if (!checkInOpenAt(window, DateTime.now())) {
      return const _Hint(
        icon: Icons.nights_stay_outlined,
        text: 'Check-in opens 2 hours before your bedtime.',
      );
    }
    return SizedBox(
      height: 58,
      child: FilledButton.icon(
        onPressed: () {
          HapticFeedback.mediumImpact();
          ref.read(nightLogRepositoryProvider).checkIn(
                pair.id,
                uid,
                DateTime.now(),
                alarm: (ref.read(myFeaturesProvider) ?? PersonalFeatures.all).alarm,
              );
        },
        icon: const Icon(Icons.bedtime),
        label: const Text('Going to sleep', style: TextStyle(fontSize: 17)),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: context.sky.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(29),
        border: Border.all(color: context.sky.outline),
      ),
      child: Row(
        children: [
          Icon(icon, color: context.sky.accent),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
