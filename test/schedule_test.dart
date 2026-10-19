import 'package:flutter_test/flutter_test.dart';
import 'package:goodnight/features/bedtime/schedule.dart';

void main() {
  test('sleep duration crosses midnight', () {
    const w = SleepWindow(bedtime: 23 * 60, wake: 6 * 60 + 30);
    expect(w.sleepMinutes, 7 * 60 + 30);
  });

  test('sleep duration within the same day', () {
    const w = SleepWindow(bedtime: 1 * 60, wake: 9 * 60);
    expect(w.sleepMinutes, 8 * 60);
  });

  test('round-trips through the stored map', () {
    const w = SleepWindow(bedtime: 22 * 60 + 5, wake: 5 * 60 + 45);
    expect(w.toMap(), {'bedtime': '22:05', 'wake': '05:45', 'grace': 5, 'pause': 10});
    expect(SleepWindow.fromMap(w.toMap()), w);
  });

  test('night-mode times default to 5 and 10 minutes and round-trip', () {
    final old = SleepWindow.fromMap({'bedtime': '23:00', 'wake': '07:00'});
    expect(old.grace, 5);
    expect(old.pause, 10);
    final agreed = old.copyWith(grace: 10, pause: 15);
    expect(SleepWindow.fromMap(agreed.toMap()), agreed);
    expect(agreed == old, isFalse);
    expect(SleepWindow.graceChoices, contains(SleepWindow.defaultGrace));
    expect(SleepWindow.pauseChoices, contains(SleepWindow.defaultPause));
  });
}
