import 'package:flutter_test/flutter_test.dart';
import 'package:goodnight/features/bedtime/schedule.dart';
import 'package:goodnight/features/checkin/night_log.dart';
import 'package:goodnight/features/sleep_widget/sleep_widget_content.dart';

const _bed23 = SleepWindow(bedtime: 23 * 60, wake: 7 * 60);
const _bed2330 = SleepWindow(bedtime: 23 * 60 + 30, wake: 7 * 60);

SleepWidgetContent _content({
  PlayerNight me = const PlayerNight(),
  PlayerNight partner = const PlayerNight(),
  SleepWindow? mine = _bed23,
  required DateTime now,
}) =>
    sleepWidgetContent(
      partnerName: 'Noob',
      me: me,
      partner: partner,
      myWindow: mine,
      partnerWindow: _bed2330,
      now: now,
    );

void main() {
  group('checkInOpenAt', () {
    test('opens 2 hours before bedtime and closes 4 hours after', () {
      expect(checkInOpenAt(_bed23, DateTime(2026, 10, 19, 20, 59)), isFalse);
      expect(checkInOpenAt(_bed23, DateTime(2026, 10, 19, 21, 0)), isTrue);
      expect(checkInOpenAt(_bed23, DateTime(2026, 10, 20, 3, 0)), isTrue);
      expect(checkInOpenAt(_bed23, DateTime(2026, 10, 20, 3, 1)), isFalse);
    });

    test('works for a bedtime just after midnight', () {
      const w = SleepWindow(bedtime: 30, wake: 8 * 60);
      expect(checkInOpenAt(w, DateTime(2026, 10, 19, 22, 30)), isTrue);
      expect(checkInOpenAt(w, DateTime(2026, 10, 19, 22, 29)), isFalse);
    });
  });

  group('sleepWidgetContent', () {
    test('offers the button when check-in is open', () {
      final c = _content(now: DateTime(2026, 10, 19, 22, 40));
      expect(c.canCheckIn, isTrue);
      expect(c.buttonLabel, 'Going to sleep');
      expect(c.meLine, 'You · bed 23:00');
      expect(c.partnerLine, 'Noob · bed 23:30');
    });

    test('says when check-in opens if it is too early', () {
      final c = _content(now: DateTime(2026, 10, 19, 18, 0));
      expect(c.canCheckIn, isFalse);
      expect(c.buttonLabel, 'Opens 21:00');
    });

    test('shows who is asleep and who is up', () {
      final c = _content(
        me: PlayerNight(checkedInAt: DateTime(2026, 10, 19, 23, 4)),
        partner: PlayerNight(
          checkedInAt: DateTime(2026, 10, 19, 23, 20),
          wokeAt: DateTime(2026, 10, 20, 6, 55),
        ),
        now: DateTime(2026, 10, 20, 7, 0),
      );
      expect(c.canCheckIn, isFalse);
      expect(c.buttonLabel, 'Sleep well');
      expect(c.meLine, 'You · asleep since 23:04');
      expect(c.partnerLine, 'Noob · up since 06:55');
    });

    test('asks for a bedtime first', () {
      final c = _content(mine: null, now: DateTime(2026, 10, 19, 22, 0));
      expect(c.canCheckIn, isFalse);
      expect(c.buttonLabel, 'Set bedtime');
      expect(c.meLine, 'You · no bedtime yet');
    });
  });

  test('partnerStatusLine', () {
    final at = DateTime(2026, 10, 19, 23, 5);
    expect(partnerStatusLine('Noob', 'asleep', at), 'Noob · asleep since 23:05');
    expect(partnerStatusLine('Noob', 'up', at), 'Noob · up since 23:05');
  });
}
