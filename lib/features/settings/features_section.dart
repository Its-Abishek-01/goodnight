import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/cute_loader.dart';
import '../alarm/wake_sound_cards.dart';
import '../bedtime/night_times_card.dart';
import '../pairing/pair.dart';
import 'features.dart';
import 'features_providers.dart';

/// The feature picker on the Setup tab. Personal features change at once;
/// shared ones go to the partner for approval.
class FeaturesSection extends ConsumerWidget {
  const FeaturesSection({super.key, required this.pair, required this.uid});

  final Pair pair;
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mine = ref.watch(myFeaturesProvider);
    final partnerUid = pair.partnerUid(uid) ?? '';
    final theirs = ref.watch(personalFeaturesProvider).value?[partnerUid] ?? PersonalFeatures.all;
    final settings = ref.watch(sharedSettingsProvider).value;
    final repo = ref.read(featuresRepositoryProvider);
    final partner = pair.nameOf(pair.partnerUid(uid) ?? '');
    final text = Theme.of(context).textTheme;

    void setMine(PersonalFeatures f) => repo.setPersonal(pair.id, uid, f);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Your features', style: text.titleMedium),
        const SizedBox(height: 4),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Smart alarm'),
                subtitle: const Text(
                  'Wake-up alarm that gets harder with every snooze. When off, '
                  'only your bedtime counts towards the streak.',
                ),
                value: mine?.alarm ?? true,
                onChanged: mine == null
                    ? null
                    : (v) => setMine(mine.copyWith(alarm: v)),
              ),
              SwitchListTile(
                title: const Text('Night mode blocking'),
                subtitle: Text(
                  'Pauses Instagram and YouTube Shorts at night.'
                  '${theirs.alertAfter > 0 ? ' $partner is told once you have been on your '
                      'phone for ${theirs.alertAfter} min after your bedtime.' : ''}',
                ),
                value: mine?.nightMode ?? true,
                onChanged: mine == null
                    ? null
                    : (v) => setMine(mine.copyWith(nightMode: v)),
              ),
              if (mine?.nightMode ?? true)
                SwitchListTile(
                  title: const Text('Watch bubble'),
                  subtitle: const Text(
                    'A little face peeks from the screen edge on Instagram and Shorts '
                    'at night, with how long you have watched and how many reels. '
                    'It gets sleepier as your pause gets closer.',
                  ),
                  value: mine?.watchBubble ?? true,
                  onChanged: mine == null
                      ? null
                      : (v) => setMine(mine.copyWith(watchBubble: v)),
                ),
              SwitchListTile(
                title: const Text('Bedtime reminders'),
                subtitle: const Text(
                  'A call wrap-up nudge and a bedtime reminder.',
                ),
                value: mine?.reminders ?? true,
                onChanged: mine == null
                    ? null
                    : (v) => setMine(mine.copyWith(reminders: v)),
              ),
            ],
          ),
        ),
        if (mine?.alarm ?? true) ...[
          const SizedBox(height: 6),
          WakeSoundCard(pair: pair, uid: uid),
        ],
        if (mine?.nightMode ?? true) ...[
          const SizedBox(height: 6),
          NightTimesCard(pair: pair, uid: uid),
        ],
        const SizedBox(height: 12),
        Text('Alerts about $partner', style: text.titleMedium),
        const SizedBox(height: 4),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tell me when $partner is still on their phone after bedtime',
                  style: text.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  theirs.nightMode
                      ? 'Any app counts, once their bedtime starts. $partner can see what you picked.'
                      : '$partner has night mode off, so their phone use is not counted.',
                  style: text.bodySmall,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final m in PersonalFeatures.alertChoices)
                      ChoiceChip(
                        label: Text(m == 0 ? 'Off' : '$m min'),
                        selected: (mine?.alertAfter ?? PersonalFeatures.defaultAlertAfter) == m,
                        onSelected: mine == null
                            ? null
                            : (_) => setMine(mine.copyWith(alertAfter: m)),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (theirs.alarm) ...[
          const SizedBox(height: 6),
          PartnerWakeSoundCard(pair: pair, uid: uid),
        ],
        const SizedBox(height: 12),
        Text('Shared with $partner', style: text.titleMedium),
        const SizedBox(height: 4),
        Card(
          child: settings == null
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CuteLoader(size: 64)),
                )
              : _SharedFeatures(pair: pair, uid: uid, settings: settings),
        ),
      ],
    );
  }
}

class _SharedFeatures extends ConsumerWidget {
  const _SharedFeatures({
    required this.pair,
    required this.uid,
    required this.settings,
  });

  final Pair pair;
  final String uid;
  final SharedSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(featuresRepositoryProvider);
    final current = settings.current;
    final proposal = settings.proposal;
    final pending = proposal != null;

    void propose(SharedFeatures f) =>
        repo.proposeShared(pairId: pair.id, by: uid, features: f);

    return Column(
      children: [
        SwitchListTile(
          title: const Text('Streak & coupons'),
          subtitle: const Text('Count good nights together and earn coupons.'),
          value: current.streak,
          onChanged: pending
              ? null
              : (v) => propose(current.copyWith(streak: v)),
        ),
        SwitchListTile(
          title: const Text('Moments'),
          subtitle: const Text('Private selfies and the home-screen widget.'),
          value: current.moments,
          onChanged: pending
              ? null
              : (v) => propose(current.copyWith(moments: v)),
        ),
        if (!pending)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text('Changes here need your partner to approve them.'),
          )
        else if (settings.by == uid)
          ListTile(
            title: Text('You asked to ${describeChange(current, proposal)}.'),
            subtitle: Text(
              'Waiting for ${pair.nameOf(pair.partnerUid(uid) ?? '')} to approve.',
            ),
            trailing: TextButton(
              onPressed: () => repo.withdrawShared(pair.id),
              child: const Text('Withdraw'),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${pair.nameOf(settings.by ?? '')} asks to '
                  '${describeChange(current, proposal)}.',
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => repo.withdrawShared(pair.id),
                      child: const Text('Decline'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => repo.approveShared(pair.id),
                      child: const Text('Approve'),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}
