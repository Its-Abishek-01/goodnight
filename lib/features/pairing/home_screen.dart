import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../bedtime/bedtime_card.dart';
import '../bedtime/schedule_providers.dart';
import 'pair.dart';

/// Home screen. Streak and coupons land here later.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, required this.pair, required this.uid});

  final Pair pair;
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partnerUid = pair.partnerUid(uid) ?? '';
    final schedules = ref.watch(schedulesProvider).value ?? const {};
    return Scaffold(
      appBar: AppBar(title: const Text('GoodNight 🌙')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'You & ${pair.nameOf(partnerUid)} are paired ❤️',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          BedtimeCard(pair: pair, me: uid, owner: uid, schedule: schedules[uid]),
          BedtimeCard(pair: pair, me: uid, owner: partnerUid, schedule: schedules[partnerUid]),
        ],
      ),
    );
  }
}
