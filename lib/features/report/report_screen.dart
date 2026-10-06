import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../checkin/night_log.dart';
import '../checkin/night_providers.dart';
import '../pairing/pair.dart';
import '../streak/streak.dart';
import '../streak/streak_providers.dart';

const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String _label(String key) {
  final d = DateTime.parse(key);
  return '${_days[d.weekday - 1]} ${d.day} ${_months[d.month - 1]}';
}

/// Last 7 nights for both of you.
class ReportScreen extends ConsumerWidget {
  const ReportScreen({super.key, required this.pair, required this.uid});

  final Pair pair;
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nights = ref.watch(nightsProvider).value ?? const <Night>[];
    final windows = ref.watch(windowsProvider);
    final streak = ref.watch(streakProvider);
    final repo = ref.read(nightLogRepositoryProvider);
    final partnerUid = pair.partnerUid(uid) ?? '';
    final members = pair.members;
    final currentKey = nightKey(DateTime.now());

    final keys = <String>[currentKey];
    while (keys.length < 7) {
      keys.add(previousKey(keys.last));
    }
    final byKey = {for (final n in nights) n.key: n};
    final week = [for (final k in keys) byKey[k]].whereType<Night>().toList();

    Widget statColumn(String name, String who) {
      var onTime = 0;
      var snoozes = 0;
      var woke = 0;
      var blocks = 0;
      var usage = 0;
      for (final n in week) {
        final p = n.playerOf(who);
        if (goodBedtime(p, windows[who]) && goodMorning(p)) onTime++;
        if (p.wokeAt != null) {
          woke++;
          snoozes += p.snoozes;
        }
        blocks += p.blocks;
        usage += p.usageMinutes;
      }
      final avg = woke == 0 ? '-' : (snoozes / woke).toStringAsFixed(1);
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            Text('On time: $onTime / ${week.length}'),
            Text('Avg snoozes: $avg'),
            Text('Night blocks: $blocks'),
            Text('Insta/Shorts: $usage min'),
          ],
        ),
      );
    }

    Color dotColor(String key) {
      final n = byKey[key];
      if (n == null) return Colors.grey;
      final complete = isComplete(n, members, currentKey);
      if (!complete) return Colors.blueGrey;
      if (isGoodNight(n, windows, members)) return Colors.green;
      return n.forgiven ? Colors.amber : Colors.redAccent;
    }

    final past = [
      for (final k in keys)
        if (byKey[k] != null && isComplete(byKey[k]!, members, currentKey)) byKey[k]!,
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('This week', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  streak.count == 0 ? 'No streak yet' : '🔥 ${streak.count}-night streak',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (final k in keys.reversed)
                      Column(
                        children: [
                          CircleAvatar(radius: 14, backgroundColor: dotColor(k)),
                          const SizedBox(height: 4),
                          Text(_days[DateTime.parse(k).weekday - 1][0]),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Green: both good · Red: missed · Amber: forgiven · Grey: no data',
                  style: TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                statColumn('You', uid),
                statColumn(pair.nameOf(partnerUid), partnerUid),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text('Nights', style: Theme.of(context).textTheme.titleMedium),
        if (past.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Finished nights will show up here.'),
          ),
        for (final n in past)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_label(n.key), style: Theme.of(context).textTheme.titleSmall),
                  for (final m in members)
                    Text(
                      '${m == uid ? 'You' : pair.nameOf(m)}: '
                      '${goodBedtime(n.playerOf(m), windows[m]) ? '✅' : '❌'} bedtime · '
                      '${goodMorning(n.playerOf(m)) ? '✅' : '❌'} morning '
                      '(${n.playerOf(m).snoozes} snoozes)',
                    ),
                  if (!isGoodNight(n, windows, members))
                    _forgiveRow(context, n, nights, uid, pair, repo),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _forgiveRow(
    BuildContext context,
    Night n,
    List<Night> nights,
    String uid,
    Pair pair,
    NightLogRepository repo,
  ) {
    if (n.forgiven) return const Text('💛 Forgiven');
    if (n.forgiveBy == uid) {
      return const Text('Waiting for your partner to agree to forgive this night...');
    }
    if (n.forgiveBy != null) {
      return Row(
        children: [
          Expanded(child: Text('${pair.nameOf(n.forgiveBy!)} asks to forgive this night')),
          FilledButton(
            onPressed: () => repo.approveForgive(pair.id, n.key),
            child: const Text('Agree'),
          ),
        ],
      );
    }
    if (!canForgiveInWeek(nights, n.key)) {
      return const Text('Forgiveness for this week is used.');
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        onPressed: () => repo.proposeForgive(pair.id, n.key, uid),
        child: const Text('Ask to forgive this night (1 per week)'),
      ),
    );
  }
}
