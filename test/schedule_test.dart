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
    expect(w.toMap(), {'bedtime': '22:05', 'wake': '05:45'});
    expect(SleepWindow.fromMap(w.toMap()), w);
  });
}
