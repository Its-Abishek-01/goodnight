import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../alarm/alarm_providers.dart';
import '../bedtime/bedtime_card.dart';
import '../bedtime/schedule_providers.dart';
import '../blocking/blocker_providers.dart';
import '../checkin/tonight_cards.dart';
import '../coupons/coupon.dart';
import '../coupons/coupon_providers.dart';
import '../coupons/coupons_screen.dart';
import '../push/push_providers.dart';
import '../reminders/reminder_providers.dart';
import '../report/report_screen.dart';
import '../selfie/moments_screen.dart';
import '../selfie/selfie_providers.dart';
import '../settings/features_providers.dart';
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
    final shared = ref.watch(sharedFeaturesProvider);
    if (shared.streak) ref.watch(couponSyncProvider);
    if (shared.moments) ref.watch(selfieSyncProvider);
    final unseen = shared.moments ? ref.watch(unseenSelfiesProvider) : 0;
    final pending = !shared.streak
        ? 0
        : (ref.watch(couponsProvider).value ?? const <Coupon>[])
            .where((c) => c.status == CouponStatus.redeemed && c.holder != widget.uid)
            .length;
    final tabs = <(NavigationDestination, Widget)>[
      (
        const NavigationDestination(icon: Icon(Icons.nights_stay_outlined), label: 'Tonight'),
        _Tonight(pair: widget.pair, uid: widget.uid, streak: shared.streak),
      ),
      (
        const NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Report'),
        ReportScreen(pair: widget.pair, uid: widget.uid),
      ),
      if (shared.moments)
        (
          NavigationDestination(
            icon: Badge(
              isLabelVisible: unseen > 0,
              label: Text('$unseen'),
              child: const Icon(Icons.photo_camera_front),
            ),
            label: 'Moments',
          ),
          MomentsScreen(pair: widget.pair, uid: widget.uid),
        ),
      if (shared.streak)
        (
          NavigationDestination(
            icon: Badge(
              isLabelVisible: pending > 0,
              label: Text('$pending'),
              child: const Icon(Icons.card_giftcard),
            ),
            label: 'Coupons',
          ),
          CouponsScreen(pair: widget.pair, uid: widget.uid),
        ),
      (
        const NavigationDestination(icon: Icon(Icons.tune), label: 'Setup'),
        SetupScreen(pair: widget.pair, uid: widget.uid),
      ),
    ];
    // A tab can disappear when the couple turns a feature off.
    final tab = _tab.clamp(0, tabs.length - 1);
    return Scaffold(
      appBar: AppBar(title: const Text('GoodNight 🌙')),
      body: tabs[tab].$2,
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [for (final t in tabs) t.$1],
      ),
    );
  }
}

class _Tonight extends ConsumerWidget {
  const _Tonight({required this.pair, required this.uid, required this.streak});

  final Pair pair;
  final String uid;
  final bool streak;

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
        if (streak) const StreakCard(),
        StatusCard(pair: pair, uid: uid),
        CheckInCard(pair: pair, uid: uid),
        BedtimeCard(pair: pair, me: uid, owner: uid, schedule: schedules[uid]),
        BedtimeCard(pair: pair, me: uid, owner: partnerUid, schedule: schedules[partnerUid]),
      ],
    );
  }
}
