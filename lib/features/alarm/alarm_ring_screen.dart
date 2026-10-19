import 'dart:async';

import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase_providers.dart';
import '../../core/theme.dart';
import '../bedtime/schedule_providers.dart';
import '../checkin/night_log.dart';
import '../checkin/night_providers.dart';
import '../pairing/pair_providers.dart';
import '../profile/profile.dart';
import '../../core/widgets/cute_loader.dart';
import 'alarm_providers.dart';
import 'alarm_scheduler.dart';
import 'challenges.dart';
import 'sunrise_sky.dart';

enum _Stage { challenge, stayUp, done }

/// Full-screen ring UI. Each snooze makes the next challenge harder.
class AlarmRingScreen extends ConsumerStatefulWidget {
  const AlarmRingScreen({super.key, required this.alarmId});

  final int alarmId;

  @override
  ConsumerState<AlarmRingScreen> createState() => _AlarmRingScreenState();
}

class _AlarmRingScreenState extends ConsumerState<AlarmRingScreen> {
  int _snoozes = 0;
  bool _qrReady = false;
  String _qrPayload = '';
  bool _loaded = false;
  _Stage _stage = _Stage.challenge;
  late final Timer _clock;
  DateTime _now = DateTime.now();

  bool get _isVerify => widget.alarmId == AlarmScheduler.verifyId;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    _load();
  }

  @override
  void dispose() {
    _clock.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final snoozes = await AlarmPrefs.snoozeCount();
    final qrReady = await AlarmPrefs.qrReady();
    final payload = qrReady ? await AlarmPrefs.qrSecret() : '';
    if (await AlarmPrefs.nightKey() == null) {
      await AlarmPrefs.setNightKey(nightKey(DateTime.now()));
    }
    if (!mounted) return;
    setState(() {
      _snoozes = snoozes;
      _qrReady = qrReady;
      _qrPayload = payload;
      _loaded = true;
    });
  }

  ChallengeKind get _kind =>
      _isVerify ? ChallengeKind.math : challengeFor(_snoozes, qrReady: _qrReady);

  Future<void> _snooze() async {
    await Alarm.stop(widget.alarmId);
    final next = _snoozes + 1;
    await AlarmPrefs.setSnoozeCount(next);
    await AlarmScheduler.scheduleSnooze(next);
    _log((repo, pairId, uid) => repo.recordSnooze(pairId, uid, DateTime.now()));
    ref.read(ringProvider.notifier).clear();
  }

  Future<void> _solved() async {
    await Alarm.stop(widget.alarmId);
    if (_isVerify) {
      final key = await AlarmPrefs.nightKey() ?? nightKey(DateTime.now());
      _log((repo, pairId, uid) => repo.recordWake(pairId, uid, DateTime.now(), key: key));
      await AlarmPrefs.setSnoozeCount(0);
      await AlarmPrefs.setNightKey(null);
      await _rescheduleTomorrow();
      if (mounted) setState(() => _stage = _Stage.done);
    } else {
      await AlarmScheduler.scheduleVerify();
      await _rescheduleTomorrow();
      if (mounted) setState(() => _stage = _Stage.stayUp);
    }
  }

  Future<void> _rescheduleTomorrow() async {
    final uid = ref.read(uidProvider).value;
    final wake = ref.read(schedulesProvider).value?[uid]?.current?.wake;
    if (wake != null) await AlarmScheduler.scheduleWake(wake);
  }

  /// Best-effort Firestore write; the alarm flow must never fail offline.
  void _log(Future<void> Function(NightLogRepository, String, String) write) {
    final pair = ref.read(pairProvider).value;
    final uid = ref.read(uidProvider).value;
    if (pair == null || uid == null) return;
    unawaited(write(ref.read(nightLogRepositoryProvider), pair.id, uid).catchError((_) {}));
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    // The ring screen always wears the warm dusk palette over its sunrise.
    return Theme(
      data: buildTheme(SkyPhase.dusk),
      child: Builder(builder: _body),
    );
  }

  Widget _body(BuildContext context) {
    final theme = Theme.of(context);
    final uid = ref.watch(uidProvider).value ?? '';
    final pair = ref.watch(pairProvider).value;
    final people = ref.watch(peopleProvider);
    final me = people[uid]?.name ?? pair?.nameOf(uid) ?? '';
    final partnerUid = pair?.partnerUid(uid) ?? '';
    final partner = people[partnerUid]?.name ?? pair?.nameOf(partnerUid) ?? '';
    final nights = ref.watch(nightsProvider).value ?? const <Night>[];
    final partnerUp = nights
            .where((n) => n.key == nightKey(_now))
            .firstOrNull
            ?.playerOf(partnerUid)
            .wokeAt !=
        null;
    final shadow = [Shadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 12)];

    final Widget panel = !_loaded
        ? const Center(child: CuteLoader(size: 96))
        : switch (_stage) {
            _Stage.stayUp => _message(
                '☕ Stay up!',
                "We'll check that you're really awake in ${AlarmScheduler.verifyMinutes} minutes.",
                'Okay',
                () => ref.read(ringProvider.notifier).clear(),
              ),
            _Stage.done => _message(
                'Have a great day ☀️',
                partnerUp ? 'Your wake-up is logged. $partner is up too.' : 'Your wake-up is logged.',
                'Close',
                () => ref.read(ringProvider.notifier).clear(),
              ),
            _Stage.challenge => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Challenge(
                    key: ValueKey('$_kind-$_snoozes-${widget.alarmId}'),
                    kind: _kind,
                    qrPayload: _qrPayload,
                    onSolved: _solved,
                  ),
                  if (!_isVerify && _snoozes < AlarmScheduler.maxSnoozes) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _snooze,
                      style: TextButton.styleFrom(foregroundColor: context.sky.muted),
                      child: Text('Snooze ${AlarmScheduler.snoozeMinutes} min · louder, harder'),
                    ),
                  ],
                ],
              ),
          };

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SunriseSky(
          child: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 36),
                Text(
                  '${_two(_now.hour)}:${_two(_now.minute)}',
                  style: theme.textTheme.displayLarge?.copyWith(
                    fontSize: 76,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    shadows: shadow,
                  ),
                ),
                Text(
                  _isVerify
                      ? 'Are you really up? Prove it.'
                      : _snoozes == 0
                          ? 'Good morning${me.isEmpty ? '' : ', $me'} ☀️'
                          : 'Snooze #$_snoozes. It gets harder each time.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(color: Colors.white, shadows: shadow),
                ),
                if (partnerUp && _stage == _Stage.challenge) ...[
                  const SizedBox(height: 8),
                  Text(
                    '$partner is already up 💛',
                    style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white, shadows: shadow),
                  ),
                ],
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Container(
                    width: double.infinity,
                    constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.55),
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                    decoration: BoxDecoration(
                      color: context.sky.surface.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: context.sky.outline),
                    ),
                    child: SingleChildScrollView(child: panel),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _message(String title, String body, String button, VoidCallback onTap) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 10),
        Text(body, textAlign: TextAlign.center),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, child: FilledButton(onPressed: onTap, child: Text(button))),
        const SizedBox(height: 8),
      ],
    );
  }
}
