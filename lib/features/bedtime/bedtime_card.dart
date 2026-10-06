import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../pairing/pair.dart';
import '../pairing/partner_color.dart';
import 'schedule.dart';
import 'schedule_providers.dart';

TimeOfDay _tod(int minutes) => TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);

String _describe(BuildContext context, SleepWindow w) {
  final h = w.sleepMinutes ~/ 60;
  final m = w.sleepMinutes % 60;
  final sleep = m == 0 ? '${h}h' : '${h}h ${m}m';
  return '${_tod(w.bedtime).format(context)} to ${_tod(w.wake).format(context)} ($sleep sleep)';
}

/// Shows one person's bedtime and the actions available to the viewer.
class BedtimeCard extends ConsumerWidget {
  const BedtimeCard({
    super.key,
    required this.pair,
    required this.me,
    required this.owner,
    required this.schedule,
  });

  final Pair pair;
  final String me;
  final String owner;
  final Schedule? schedule;

  bool get _isMine => owner == me;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(scheduleRepositoryProvider);
    final otherName = pair.nameOf(_isMine ? pair.partnerUid(me) ?? '' : me);
    final title = _isMine ? 'Your bedtime' : "${pair.nameOf(owner)}'s bedtime";
    final current = schedule?.current;
    final proposal = schedule?.proposal;

    Future<void> propose(SleepWindow? initial) async {
      final w = await showDialog<SleepWindow>(
        context: context,
        builder: (_) => _WindowDialog(initial: initial),
      );
      if (w == null) return;
      await repo.propose(pairId: pair.id, owner: owner, by: me, window: w);
    }

    final lines = <Widget>[];
    final actions = <Widget>[];

    if (current != null) {
      lines.add(Text('🔒 ${_describe(context, current)}'));
    }

    if (proposal != null && proposal.by == me) {
      lines.add(Text('Waiting for $otherName to approve: ${_describe(context, proposal.window)}'));
      actions.add(TextButton(
        onPressed: () => propose(proposal.window),
        child: const Text('Change proposal'),
      ));
    } else if (proposal != null) {
      lines.add(Text('$otherName suggests ${_describe(context, proposal.window)}'));
      actions.add(FilledButton(
        onPressed: () => repo.approve(pairId: pair.id, owner: owner),
        child: const Text('Approve'),
      ));
      actions.add(OutlinedButton(
        onPressed: () => propose(proposal.window),
        child: const Text('Suggest different'),
      ));
    } else if (current != null && _isMine) {
      actions.add(OutlinedButton(
        onPressed: () => propose(current),
        child: const Text('Request a change'),
      ));
    } else if (current == null) {
      if (_isMine) {
        lines.add(const Text('Not set yet'));
        actions.add(FilledButton(
          onPressed: () => propose(null),
          child: const Text('Set my bedtime'),
        ));
      } else {
        lines.add(Text('Waiting for ${pair.nameOf(owner)} to set it'));
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                PartnerAvatar(name: pair.nameOf(owner), color: pair.colorOf(owner), size: 28),
                const SizedBox(width: 10),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            ...lines,
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: actions),
            ],
          ],
        ),
      ),
    );
  }
}

class _WindowDialog extends StatefulWidget {
  const _WindowDialog({this.initial});

  final SleepWindow? initial;

  @override
  State<_WindowDialog> createState() => _WindowDialogState();
}

class _WindowDialogState extends State<_WindowDialog> {
  late TimeOfDay _bed = _tod(widget.initial?.bedtime ?? 23 * 60);
  late TimeOfDay _wake = _tod(widget.initial?.wake ?? 6 * 60 + 30);

  Future<void> _pick(bool bed) async {
    final t = await showTimePicker(context: context, initialTime: bed ? _bed : _wake);
    if (t == null) return;
    setState(() => bed ? _bed = t : _wake = t);
  }

  SleepWindow get _window => SleepWindow(
        bedtime: _bed.hour * 60 + _bed.minute,
        wake: _wake.hour * 60 + _wake.minute,
      );

  @override
  Widget build(BuildContext context) {
    final valid = _window.bedtime != _window.wake;
    return AlertDialog(
      title: const Text('Bedtime'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: const Text('Bedtime'),
            trailing: Text(_bed.format(context)),
            onTap: () => _pick(true),
          ),
          ListTile(
            title: const Text('Wake up'),
            trailing: Text(_wake.format(context)),
            onTap: () => _pick(false),
          ),
          if (valid) Text('${_window.sleepMinutes ~/ 60}h ${_window.sleepMinutes % 60}m of sleep'),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: valid ? () => Navigator.pop(context, _window) : null,
          child: const Text('Send for approval'),
        ),
      ],
    );
  }
}
