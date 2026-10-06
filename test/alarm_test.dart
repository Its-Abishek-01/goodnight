import 'package:flutter_test/flutter_test.dart';
import 'package:goodnight/features/alarm/alarm_scheduler.dart';
import 'package:goodnight/features/alarm/challenges.dart';
import 'package:goodnight/features/checkin/night_log.dart';

void main() {
  test('challenge gets harder with each snooze', () {
    expect(challengeFor(0, qrReady: true), ChallengeKind.tap);
    expect(challengeFor(1, qrReady: true), ChallengeKind.math);
    expect(challengeFor(2, qrReady: true), ChallengeKind.type);
    expect(challengeFor(3, qrReady: true), ChallengeKind.qr);
    expect(challengeFor(5, qrReady: true), ChallengeKind.qr);
  });

  test('QR challenge falls back to typing when no QR is set up', () {
    expect(challengeFor(3, qrReady: false), ChallengeKind.type);
  });

  test('volume rises with each snooze and caps at 1.0', () {
    final v = [for (var i = 0; i < 7; i++) AlarmScheduler.volumeFor(i)];
    for (var i = 1; i < v.length; i++) {
      expect(v[i], greaterThanOrEqualTo(v[i - 1]));
    }
    expect(v.last, 1.0);
  });

  test('next wake is today when still ahead, otherwise tomorrow', () {
    final morning = DateTime(2026, 10, 6, 5, 0);
    expect(AlarmScheduler.nextWake(6 * 60 + 30, morning), DateTime(2026, 10, 6, 6, 30));
    final later = DateTime(2026, 10, 6, 6, 31);
    expect(AlarmScheduler.nextWake(6 * 60 + 30, later), DateTime(2026, 10, 7, 6, 30));
  });

  test('night key groups bedtime and morning into the same night', () {
    expect(nightKey(DateTime(2026, 10, 6, 23, 0)), '2026-10-06');
    expect(nightKey(DateTime(2026, 10, 7, 2, 0)), '2026-10-06');
    expect(nightKey(DateTime(2026, 10, 7, 7, 0)), '2026-10-06');
    expect(nightKey(DateTime(2026, 10, 7, 13, 0)), '2026-10-07');
  });
}
