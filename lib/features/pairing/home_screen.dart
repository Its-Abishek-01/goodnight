import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import '../../core/sky_phase.dart';
import '../../core/widgets/cute_icons.dart';
import '../../core/widgets/moon_nav_bar.dart';

import '../alarm/alarm_providers.dart';
import '../alarm/wake_sound_providers.dart';
import '../bedtime/bedtime_card.dart';
import '../bedtime/schedule_providers.dart';
import '../blocking/blocker_providers.dart';
import '../blocking/night_mode_off_card.dart';
import '../blocking/time_request_card.dart';
import '../checkin/tonight_cards.dart';
import '../coupons/coupon.dart';
import '../coupons/coupon_providers.dart';
import '../coupons/coupons_screen.dart';
import '../lovenote/love_note_compose.dart';
import '../lovenote/love_note_providers.dart';
import '../push/push_providers.dart';
import '../reminders/reminder_providers.dart';
import '../report/report_screen.dart';
import '../selfie/moments_screen.dart';
import '../selfie/selfie_providers.dart';
import '../settings/features_providers.dart';
import '../setup/setup_screen.dart';
import '../sleep_widget/sleep_widget.dart';
import '../update/update_providers.dart';
import '../update/update_widgets.dart';
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
  CuteIconKind _tab = CuteIconKind.tonight;
  final _taps = <CuteIconKind, int>{};

  String? _offeredTag;
  StreamSubscription<Uri?>? _widgetClicks;

  /// The launch that opened the app is handled once, not on every rebuild of Home.
  static bool _handledLaunch = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    syncBlockStats(ref);
    // The check may have finished before Home was first shown.
    WidgetsBinding.instance.addPostFrameCallback((_) => _offerUpdate(ref.read(updateProvider)));
    _widgetClicks = HomeWidget.widgetClicked.listen(_onWidgetUri, onError: (_) {});
    if (!_handledLaunch) {
      _handledLaunch = true;
      HomeWidget.initiallyLaunchedFromHomeWidget().then(_onWidgetUri).catchError((_) {});
    }
  }

  /// The "Going to sleep" widget's button opens the app with [SleepHomeWidget.checkInUri].
  Future<void> _onWidgetUri(Uri? uri) async {
    if (uri?.toString() != SleepHomeWidget.checkInUri) return;
    final message = await checkInFromWidget(ref);
    if (message == null || !mounted) return;
    setState(() => _tab = CuteIconKind.tonight);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Slides up the update sheet once per release (required updates have their own
  /// screen in the gate).
  void _offerUpdate(UpdateState s) {
    final r = s.release;
    if (!mounted || r == null || r.required || r.tag == _offeredTag) return;
    _offeredTag = r.tag;
    showUpdateSheet(context, ref);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _widgetClicks?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) syncBlockStats(ref);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(updateProvider, (_, next) => _offerUpdate(next));
    ref.watch(alarmSyncProvider);
    ref.watch(blockerSyncProvider);
    ref.watch(reminderSyncProvider);
    ref.watch(pushSyncProvider);
    ref.watch(loveNoteSyncProvider);
    ref.watch(sleepWidgetSyncProvider);
    ref.watch(timeRequestSyncProvider);
    ref.watch(wakeSoundSyncProvider);
    final shared = ref.watch(sharedFeaturesProvider);
    if (shared.streak) ref.watch(couponSyncProvider);
    if (shared.moments) ref.watch(selfieSyncProvider);
    final unseen = shared.moments ? ref.watch(unseenSelfiesProvider) : 0;
    final pending = !shared.streak
        ? 0
        : (ref.watch(couponsProvider).value ?? const <Coupon>[])
            .where((c) => c.status == CouponStatus.redeemed && c.holder != widget.uid)
            .length;
    final pages = <CuteIconKind, Widget>{
      CuteIconKind.tonight: _Tonight(pair: widget.pair, uid: widget.uid, streak: shared.streak),
      CuteIconKind.week: ReportScreen(pair: widget.pair, uid: widget.uid),
      if (shared.moments) CuteIconKind.moments: MomentsScreen(pair: widget.pair, uid: widget.uid),
      if (shared.streak) CuteIconKind.coupons: CouponsScreen(pair: widget.pair, uid: widget.uid),
      CuteIconKind.us: SetupScreen(pair: widget.pair, uid: widget.uid),
    };
    // A tab disappears when the couple turns its feature off.
    final tab = pages.containsKey(_tab) ? _tab : CuteIconKind.tonight;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            // Long-press the logo to preview dawn, day, dusk and night.
            GestureDetector(
              onLongPress: () {
                final p = ref.read(skyPhaseProvider.notifier).cyclePreview();
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(SnackBar(
                    content: Text(p == null ? 'Sky follows the time again' : 'Sky preview: ${p.name}'),
                    duration: const Duration(seconds: 2),
                  ));
              },
              child: Image.asset('assets/logo.png', width: 30, height: 30),
            ),
            const SizedBox(width: 10),
            const Text('GoodNight', style: TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
      body: pages[tab],
      bottomNavigationBar: MoonNavBar(
        selected: tab,
        taps: _taps,
        onSelect: (k) => setState(() {
          _tab = k;
          _taps[k] = (_taps[k] ?? 0) + 1;
        }),
        left: [
          const MoonNavItem(CuteIconKind.week, 'Our week'),
          if (shared.moments) MoonNavItem(CuteIconKind.moments, 'Moments', badge: unseen),
        ],
        right: [
          if (shared.streak) MoonNavItem(CuteIconKind.coupons, 'Coupons', badge: pending),
          const MoonNavItem(CuteIconKind.us, 'Us'),
        ],
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
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        Row(
          children: [
            Text(
              Theme.of(context).brightness == Brightness.light ? 'Today' : 'Tonight',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            if (streak) const StreakChip(),
          ],
        ),
        const SizedBox(height: 8),
        const NightModeOffCard(),
        TimeRequestCard(pair: pair, uid: uid),
        TonightJourney(pair: pair, uid: uid),
        const SizedBox(height: 12),
        SnoozeNudge(pair: pair, uid: uid),
        const SizedBox(height: 8),
        CheckInButton(pair: pair, uid: uid),
        const SizedBox(height: 16),
        PartnerTonight(pair: pair, uid: uid),
        const SizedBox(height: 12),
        LoveNoteButton(pair: pair, uid: uid),
        const SizedBox(height: 24),
        Text('Bedtimes', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        BedtimeCard(pair: pair, me: uid, owner: uid, schedule: schedules[uid]),
        BedtimeCard(pair: pair, me: uid, owner: partnerUid, schedule: schedules[partnerUid]),
      ],
    );
  }
}
