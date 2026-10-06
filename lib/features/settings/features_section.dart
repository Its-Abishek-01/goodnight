import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
                subtitle: const Text(
                  'Pauses Instagram and YouTube Shorts at night.',
                ),
                value: mine?.nightMode ?? true,
                onChanged: mine == null
                    ? null
                    : (v) => setMine(mine.copyWith(nightMode: v)),
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
        const SizedBox(height: 12),
        Text('Shared with $partner', style: text.titleMedium),
        const SizedBox(height: 4),
        Card(
          child: settings == null
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
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
