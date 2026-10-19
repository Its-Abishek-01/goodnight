import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../pairing/pair.dart';
import '../profile/profile.dart';
import 'schedule.dart';
import 'schedule_providers.dart';

/// "Night mode times" on the Us tab: how many minutes of Instagram/Shorts
/// before a pause, and how long the pause lasts. Like the bedtime, a change
/// goes to the partner for approval (on their Tonight tab, in your bedtime
/// card) and the approved times stay in force until then.
class NightTimesCard extends ConsumerStatefulWidget {
  const NightTimesCard({super.key, required this.pair, required this.uid});

  final Pair pair;
  final String uid;

  @override
  ConsumerState<NightTimesCard> createState() => _NightTimesCardState();
}

class _NightTimesCardState extends ConsumerState<NightTimesCard> {
  int? _grace;
  int? _pause;
  bool _sending = false;

  @override
  Widget build(BuildContext context) {
    final schedule = ref.watch(schedulesProvider).value?[widget.uid];
    final current = schedule?.current;
    final proposal = schedule?.proposal;
    final partnerUid = widget.pair.partnerUid(widget.uid) ?? '';
    final partner =
        ref.watch(peopleProvider)[partnerUid]?.name ??
        widget.pair.nameOf(partnerUid);
    final text = Theme.of(context).textTheme;
    final muted = text.bodySmall?.copyWith(color: context.sky.muted);

    // Start from a pending proposal, else the approved times.
    final base = proposal?.window ?? current;
    final grace = _grace ?? base?.grace ?? SleepWindow.defaultGrace;
    final pause = _pause ?? base?.pause ?? SleepWindow.defaultPause;
    final changed =
        base != null && (grace != base.grace || pause != base.pause);

    Future<void> send() async {
      if (base == null) return;
      setState(() => _sending = true);
      try {
        await ref
            .read(scheduleRepositoryProvider)
            .propose(
              pairId: widget.pair.id,
              owner: widget.uid,
              by: widget.uid,
              window: base.copyWith(grace: grace, pause: pause),
            );
        if (mounted) setState(() => _grace = _pause = null);
      } finally {
        if (mounted) setState(() => _sending = false);
      }
    }

    Widget choices(List<int> values, int selected, ValueChanged<int> onPick) =>
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final v in values)
              ChoiceChip(
                label: Text('$v min'),
                selected: v == selected,
                onSelected: base == null ? null : (_) => onPick(v),
              ),
          ],
        );

    return SizedBox(
      width: double.infinity,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Night mode times', style: text.titleSmall),
              const SizedBox(height: 2),
              Text(
                base == null
                    ? 'Set your bedtime on the Tonight tab first.'
                    : 'Agreed with $partner. A change needs their OK.',
                style: muted,
              ),
              const SizedBox(height: 12),
              Text('Instagram/Shorts before a pause', style: text.bodyMedium),
              const SizedBox(height: 6),
              choices(
                SleepWindow.graceChoices,
                grace,
                (v) => setState(() => _grace = v),
              ),
              const SizedBox(height: 12),
              Text('Pause length', style: text.bodyMedium),
              const SizedBox(height: 6),
              choices(
                SleepWindow.pauseChoices,
                pause,
                (v) => setState(() => _pause = v),
              ),
              if (changed) ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _sending ? null : send,
                    child: Text('Ask $partner to approve'),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              if (current != null)
                Text(
                  'Now: ${current.grace} min, then a ${current.pause} min pause.',
                  style: muted,
                ),
              if (proposal != null && proposal.by == widget.uid && !changed)
                Text(
                  'Waiting for $partner: ${proposal.window.grace} min, then a ${proposal.window.pause} min pause.',
                  style: muted,
                ),
              if (proposal != null && proposal.by != widget.uid)
                Text(
                  '$partner suggested a change. Approve it in your bedtime on the Tonight tab.',
                  style: muted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
