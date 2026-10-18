import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_update.dart';
import 'updater.dart';

enum UpdatePhase { ready, downloading, needsPermission, installing, failed }

/// The update on offer (null when there is none) and how far it has got.
@immutable
class UpdateState {
  const UpdateState({
    this.release,
    this.installed = '',
    this.phase = UpdatePhase.ready,
    this.progress = 0,
  });

  final AppRelease? release;

  /// The installed version name, e.g. `0.2.1`.
  final String installed;
  final UpdatePhase phase;

  /// 0..1 while downloading.
  final double progress;

  bool get busy =>
      phase == UpdatePhase.downloading || phase == UpdatePhase.installing;

  UpdateState copyWith({UpdatePhase? phase, double? progress}) => UpdateState(
        release: release,
        installed: installed,
        phase: phase ?? this.phase,
        progress: progress ?? this.progress,
      );
}

/// Looks for a newer GitHub release when the app starts and when it comes
/// back to the front (at most every few hours), and runs the update.
class UpdateNotifier extends Notifier<UpdateState> {
  static const _checkEvery = Duration(hours: 3);
  static const _snooze = Duration(days: 1);
  static const _kSnoozeTag = 'update.snoozeTag';
  static const _kSnoozeUntil = 'update.snoozeUntil';

  DateTime? _lastCheck;
  File? _apk;

  @override
  UpdateState build() {
    final life = AppLifecycleListener(onResume: _onResume);
    ref.onDispose(life.dispose);
    Future.microtask(check);
    return const UpdateState();
  }

  Future<void> check({bool force = false}) async {
    // Debug builds are signed with a different key, so a release APK could
    // never install over them.
    if (kDebugMode) return;
    if (state.busy || state.phase == UpdatePhase.needsPermission) return;
    final now = DateTime.now();
    if (!force && _lastCheck != null && now.difference(_lastCheck!) < _checkEvery) return;
    _lastCheck = now;
    try {
      final release = await Updater.fetchLatest();
      if (release == null) return;
      final installed = await Updater.installedVersion();
      final prefs = await SharedPreferences.getInstance();
      final until = prefs.getInt(_kSnoozeUntil);
      final offer = shouldOffer(
        release: release,
        installed: installed,
        now: now,
        snoozedTag: prefs.getString(_kSnoozeTag),
        snoozedUntil: until == null ? null : DateTime.fromMillisecondsSinceEpoch(until),
      );
      if (state.busy) return;
      state = UpdateState(release: offer ? release : null, installed: installed);
    } catch (_) {
      // Offline or GitHub unreachable: try again next time.
    }
  }

  /// "Later": hide this release for a day.
  Future<void> later() async {
    final r = state.release;
    if (r == null || r.required) return;
    state = const UpdateState();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSnoozeTag, r.tag);
    await prefs.setInt(_kSnoozeUntil, DateTime.now().add(_snooze).millisecondsSinceEpoch);
  }

  /// Downloads the APK (reusing a finished download) and opens the installer.
  Future<void> start() async {
    final r = state.release;
    if (r == null || state.busy) return;
    state = state.copyWith(phase: UpdatePhase.downloading, progress: 0);
    try {
      var shown = 0;
      _apk = await Updater.download(r, onProgress: (p) {
        final pct = (p * 100).floor();
        if (pct == shown) return;
        shown = pct;
        state = state.copyWith(progress: p);
      });
    } catch (_) {
      state = state.copyWith(phase: UpdatePhase.failed);
      return;
    }
    await _install();
  }

  /// Opens the "Install unknown apps" switch; the install carries on when the
  /// person comes back with it turned on.
  Future<void> allowInstalls() => Updater.openInstallSettings();

  Future<void> _install() async {
    final apk = _apk;
    if (apk == null) return;
    try {
      if (!await Updater.canInstall()) {
        state = state.copyWith(phase: UpdatePhase.needsPermission);
        return;
      }
      state = state.copyWith(phase: UpdatePhase.installing, progress: 1);
      await Updater.install(apk);
    } catch (_) {
      state = state.copyWith(phase: UpdatePhase.failed);
    }
  }

  void _onResume() {
    switch (state.phase) {
      case UpdatePhase.needsPermission:
        _install();
      case UpdatePhase.installing:
        // Back from the installer without updating (cancelled or blocked).
        state = state.copyWith(phase: UpdatePhase.ready);
      default:
        check();
    }
  }
}

final updateProvider = NotifierProvider<UpdateNotifier, UpdateState>(UpdateNotifier.new);
