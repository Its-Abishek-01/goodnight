import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../alarm/alarm_providers.dart';
import '../bedtime/bedtime_card.dart';
import '../bedtime/schedule_providers.dart';
import '../blocking/blocker_providers.dart';
import '../checkin/tonight_cards.dart';
import '../push/push_providers.dart';
import '../reminders/reminder_providers.dart';
import '../report/report_screen.dart';
import '../setup/setup_screen.dart';
import 'pair.dart';

/// App shell with the main tabs.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key, required this.pair, required this.uid});

  final Pair pair;
  final String uid;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    syncBlockStats(ref);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) syncBlockStats(ref);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(alarmSyncProvider);
    ref.watch(blockerSyncProvider);
    ref.watch(reminderSyncProvider);
    ref.watch(pushSyncProvider);
    final pages = <Widget>[
      _Tonight(pair: widget.pair, uid: widget.uid),
      ReportScreen(pair: widget.pair, uid: widget.uid),
      const SetupScreen(),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('GoodNight 🌙')),
      body: pages[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.nights_stay_outlined), label: 'Tonight'),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Report'),
          NavigationDestination(icon: Icon(Icons.tune), label: 'Setup'),
        ],
      ),
    );
  }
}

class _Tonight extends ConsumerWidget {
  const _Tonight({required this.pair, required this.uid});

  final Pair pair;
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partnerUid = pair.partnerUid(uid) ?? '';
    final schedules = ref.watch(schedulesProvider).value ?? const {};
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'You & ${pair.nameOf(partnerUid)} are paired ❤️',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        const StreakCard(),
        StatusCard(pair: pair, uid: uid),
        CheckInCard(pair: pair, uid: uid),
        BedtimeCard(pair: pair, me: uid, owner: uid, schedule: schedules[uid]),
        BedtimeCard(pair: pair, me: uid, owner: partnerUid, schedule: schedules[partnerUid]),
      ],
    );
  }
}
