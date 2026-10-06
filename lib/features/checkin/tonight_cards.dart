import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../pairing/pair.dart';
import '../settings/features.dart';
import '../settings/features_providers.dart';
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
      backgroundColor: GnColors.surface,
      side: const BorderSide(color: GnColors.outline),
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
    return MoonJourney(
      me: _tonight(ref, uid),
      partner: _tonight(ref, partnerUid),
      myName: pair.nameOf(uid),
      partnerName: pair.nameOf(partnerUid),
      myColor: pair.colorOf(uid),
      partnerColor: pair.colorOf(partnerUid),
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
      color: const Color(0xFF5A2236),
      child: ListTile(
        leading: const Icon(Icons.phone_in_talk, color: GnColors.moon),
        title: Text('${pair.nameOf(partnerUid)} has snoozed ${p.snoozes} times'),
        subtitle: const Text('Maybe give them a call.'),
      ),
    );
  }
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
    if (mine.checkedInAt != null) {
      return _Hint(
        icon: Icons.check_circle,
        text: 'Checked in at ${_time(context, mine.checkedInAt!)}. Phone down, sleep well.',
      );
    }
    final now = DateTime.now();
    final delta = (((now.hour * 60 + now.minute) - window.bedtime + 720) % 1440) - 720;
    if (delta < -120 || delta > 240) {
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
        color: GnColors.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(29),
        border: Border.all(color: GnColors.outline),
      ),
      child: Row(
        children: [
          Icon(icon, color: GnColors.moon),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
