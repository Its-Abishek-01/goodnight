import 'dart:math';

import 'package:alarm/alarm.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Schedules the wake alarm and its escalation. Each snooze makes the next
/// ring louder and the dismiss challenge harder.
class AlarmScheduler {
  static const wakeId = 1001;
  static const snoozeId = 1002;
  static const verifyId = 1003;

  static const snoozeMinutes = 5;
  static const verifyMinutes = 8;
  static const maxSnoozes = 5;

  static const _volumes = [0.4, 0.55, 0.7, 0.85, 1.0];

  static double volumeFor(int level) =>
      _volumes[level.clamp(0, _volumes.length - 1)];

  /// The next time [wakeMinute] (minutes since midnight) occurs after [now].
  static DateTime nextWake(int wakeMinute, DateTime now) {
    var t = DateTime(now.year, now.month, now.day, wakeMinute ~/ 60, wakeMinute % 60);
    if (!t.isAfter(now)) t = t.add(const Duration(days: 1));
    return t;
  }

  static Future<void> _set({
    required int id,
    required DateTime when,
    required int level,
    required String title,
    required String body,
  }) async {
    await Alarm.set(
      alarmSettings: AlarmSettings(
        id: id,
        dateTime: when,
        assetAudioPath: 'assets/alarm.wav',
        loopAudio: true,
        vibrate: true,
        volume: volumeFor(level),
        volumeEnforced: level >= 2,
        fadeDuration: level == 0 ? 15 : 0,
        warningNotificationOnKill: true,
        androidFullScreenIntent: true,
        notificationSettings: NotificationSettings(title: title, body: body),
      ),
    );
  }

  /// Schedules tomorrow's (or today's) wake alarm. Does nothing while an
  /// alarm is ringing so it can never replace the ring the user is solving.
  static Future<void> scheduleWake(int wakeMinute, {DateTime? now}) async {
    if (await Alarm.isRinging()) return;
    await _set(
      id: wakeId,
      when: nextWake(wakeMinute, now ?? DateTime.now()),
      level: 0,
      title: 'Good morning ☀️',
      body: 'Time to wake up. Open GoodNight to turn this off.',
    );
  }

  static Future<void> cancelWake() => Alarm.stop(wakeId);

  static Future<void> scheduleSnooze(int level) => _set(
        id: snoozeId,
        when: DateTime.now().add(const Duration(minutes: snoozeMinutes)),
        level: level,
        title: 'Wake up! ⏰',
        body: 'Snooze #$level. It gets louder and harder each time.',
      );

  static Future<void> scheduleVerify() => _set(
        id: verifyId,
        when: DateTime.now().add(const Duration(minutes: verifyMinutes)),
        level: 3,
        title: 'Are you really up? 👀',
        body: 'Open GoodNight to confirm you are out of bed.',
      );

  static Future<void> stopAll() => Alarm.stopAll();
}

/// Small persisted state for the current morning and the alarm QR code.
class AlarmPrefs {
  static const _snoozeKey = 'alarm.snoozeCount';
  static const _qrSecretKey = 'alarm.qrSecret';
  static const _qrReadyKey = 'alarm.qrReady';
  static const _nightKeyKey = 'alarm.nightKey';

  static Future<int> snoozeCount() async =>
      (await SharedPreferences.getInstance()).getInt(_snoozeKey) ?? 0;

  static Future<void> setSnoozeCount(int v) async =>
      (await SharedPreferences.getInstance()).setInt(_snoozeKey, v);

  /// Night key remembered when the morning's alarm first rang, so the wake is
  /// logged to the right night even if it is confirmed after noon.
  static Future<String?> nightKey() async =>
      (await SharedPreferences.getInstance()).getString(_nightKeyKey);

  static Future<void> setNightKey(String? v) async {
    final p = await SharedPreferences.getInstance();
    v == null ? await p.remove(_nightKeyKey) : await p.setString(_nightKeyKey, v);
  }

  static Future<String> qrSecret() async {
    final p = await SharedPreferences.getInstance();
    var s = p.getString(_qrSecretKey);
    if (s == null) {
      const chars = 'abcdefghijkmnpqrstuvwxyz23456789';
      final r = Random.secure();
      s = List.generate(14, (_) => chars[r.nextInt(chars.length)]).join();
      await p.setString(_qrSecretKey, s);
    }
    return 'goodnight:$s';
  }

  static Future<bool> qrReady() async =>
      (await SharedPreferences.getInstance()).getBool(_qrReadyKey) ?? false;

  static Future<void> setQrReady(bool v) async =>
      (await SharedPreferences.getInstance()).setBool(_qrReadyKey, v);
}
