import 'dart:async';

import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase_providers.dart';
import '../bedtime/schedule_providers.dart';
import '../checkin/night_log.dart';
import '../checkin/night_providers.dart';
import '../pairing/pair_providers.dart';
import 'alarm_providers.dart';
import 'alarm_scheduler.dart';
import 'challenges.dart';

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
    final theme = Theme.of(context);
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: !_loaded
                ? const Center(child: CircularProgressIndicator())
                : switch (_stage) {
                    _Stage.stayUp => _message(
                        '☕ Stay up!',
                        "We'll check that you're really awake in ${AlarmScheduler.verifyMinutes} minutes.",
                        'Okay',
                        () => ref.read(ringProvider.notifier).clear(),
                      ),
                    _Stage.done => _message(
                        'Have a great day ☀️',
                        'Your wake-up is logged.',
                        'Close',
                        () => ref.read(ringProvider.notifier).clear(),
                      ),
                    _Stage.challenge => ListView(
                        children: [
                          const SizedBox(height: 24),
                          Center(
                            child: Text(
                              '${_two(_now.hour)}:${_two(_now.minute)}',
                              style: theme.textTheme.displayLarge,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Center(
                            child: Text(
                              _isVerify
                                  ? 'Are you really up? Prove it.'
                                  : _snoozes == 0
                                      ? 'Good morning ☀️'
                                      : 'Snooze #$_snoozes. It gets harder each time.',
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                          const SizedBox(height: 32),
                          Challenge(
                            key: ValueKey('$_kind-$_snoozes-${widget.alarmId}'),
                            kind: _kind,
                            qrPayload: _qrPayload,
                            onSolved: _solved,
                          ),
                          if (!_isVerify && _snoozes < AlarmScheduler.maxSnoozes) ...[
                            const SizedBox(height: 32),
                            TextButton(
                              onPressed: _snooze,
                              child: Text(
                                'Snooze ${AlarmScheduler.snoozeMinutes} min (louder and harder)',
                              ),
                            ),
                          ],
                        ],
                      ),
                  },
          ),
        ),
      ),
    );
  }

  Widget _message(String title, String body, String button, VoidCallback onTap) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        Text(body, textAlign: TextAlign.center),
        const SizedBox(height: 32),
        FilledButton(onPressed: onTap, child: Text(button)),
      ],
    );
  }
}
