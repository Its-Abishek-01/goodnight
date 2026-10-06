import 'package:flutter_test/flutter_test.dart';
import 'package:goodnight/features/bedtime/schedule.dart';
import 'package:goodnight/features/checkin/night_log.dart';
import 'package:goodnight/features/streak/streak.dart';

const _members = ['a', 'b'];
final _windows = {
  'a': const SleepWindow(bedtime: 23 * 60, wake: 6 * 60 + 30),
  'b': const SleepWindow(bedtime: 22 * 60 + 30, wake: 6 * 60),
};

PlayerNight _good(String key, {int hour = 22, int minute = 50, int snoozes = 0}) {
  final d = DateTime.parse(key);
  return PlayerNight(
    checkedInAt: DateTime(d.year, d.month, d.day, hour, minute),
    wokeAt: DateTime(d.year, d.month, d.day + 1, 6, 40),
    snoozes: snoozes,
  );
}

Night _night(String key, {PlayerNight? a, PlayerNight? b, bool forgiven = false}) =>
    Night(
      key: key,
      players: {'a': a ?? _good(key), 'b': b ?? _good(key, hour: 22, minute: 20)},
      forgiven: forgiven,
    );

void main() {
  test('check-in must be near bedtime', () {
    final w = _windows['a'];
    final key = '2026-10-06';
    expect(goodBedtime(_good(key, hour: 23, minute: 10), w), isTrue);
    expect(goodBedtime(_good(key, hour: 23, minute: 20), w), isFalse);
    expect(goodBedtime(_good(key, hour: 22, minute: 0), w), isTrue);
    expect(goodBedtime(_good(key, hour: 12, minute: 0), w), isFalse);
    expect(goodBedtime(const PlayerNight(), w), isFalse);
  });

  test('too many snoozes is not a good morning', () {
    expect(goodMorning(_good('2026-10-06', snoozes: 3)), isTrue);
    expect(goodMorning(_good('2026-10-06', snoozes: 4)), isFalse);
  });

  test('streak counts consecutive good nights up to the latest', () {
    final nights = [
      _night('2026-10-06'),
      _night('2026-10-05'),
      _night('2026-10-04'),
    ];
    final s = computeStreak(nights, _windows, _members, '2026-10-06');
    expect(s.count, 3);
    expect(s.startKey, '2026-10-04');
  });

  test('a night still in progress does not break the streak', () {
    final inProgress = Night(
      key: '2026-10-06',
      players: {'a': PlayerNight(checkedInAt: DateTime(2026, 10, 6, 22, 55))},
    );
    final nights = [inProgress, _night('2026-10-05'), _night('2026-10-04')];
    expect(computeStreak(nights, _windows, _members, '2026-10-06').count, 2);
  });

  test('a failed finished night resets the streak', () {
    final bad = _night('2026-10-06', a: _good('2026-10-06', snoozes: 5));
    final nights = [bad, _night('2026-10-05')];
    expect(computeStreak(nights, _windows, _members, '2026-10-06').count, 0);
  });

  test('a gap in the log ends the streak', () {
    final nights = [_night('2026-10-06'), _night('2026-10-04')];
    expect(computeStreak(nights, _windows, _members, '2026-10-06').count, 1);
  });

  test('a forgiven night keeps the streak alive without counting', () {
    final bad = _night('2026-10-05', a: _good('2026-10-05', snoozes: 5), forgiven: true);
    final nights = [_night('2026-10-06'), bad, _night('2026-10-04')];
    final s = computeStreak(nights, _windows, _members, '2026-10-06');
    expect(s.count, 2);
    expect(s.startKey, '2026-10-04');
  });

  test('only one forgiveness is available per week', () {
    final forgiven = _night('2026-10-05', forgiven: true); // Monday
    expect(canForgiveInWeek([forgiven], '2026-10-07'), isFalse);
    expect(canForgiveInWeek([forgiven], '2026-10-12'), isTrue);
  });

  test('previousKey crosses month boundaries', () {
    expect(previousKey('2026-10-01'), '2026-09-30');
    expect(previousKey('2026-01-01'), '2025-12-31');
  });
}
