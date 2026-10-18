import '../bedtime/schedule.dart';
import '../checkin/night_log.dart';

/// Check-in opens 2 hours before bedtime and stays open until 4 hours after.
bool checkInOpenAt(SleepWindow w, DateTime now) {
  final delta = (((now.hour * 60 + now.minute) - w.bedtime + 720) % 1440) - 720;
  return delta >= -120 && delta <= 240;
}

String _hm(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

String _clock(DateTime t) => _hm(t.hour * 60 + t.minute);

/// What the "Going to sleep" home-screen widget shows.
class SleepWidgetContent {
  const SleepWidgetContent({
    required this.meLine,
    required this.partnerLine,
    required this.buttonLabel,
    required this.canCheckIn,
  });

  final String meLine;
  final String partnerLine;
  final String buttonLabel;

  /// Tapping the button checks you in (otherwise it just opens the app).
  final bool canCheckIn;
}

String _status(String who, PlayerNight p, SleepWindow? w) {
  if (p.wokeAt != null) return '$who · up since ${_clock(p.wokeAt!)}';
  if (p.checkedInAt != null) return '$who · asleep since ${_clock(p.checkedInAt!)}';
  if (w == null) return '$who · no bedtime yet';
  return '$who · bed ${_hm(w.bedtime)}';
}

SleepWidgetContent sleepWidgetContent({
  required String partnerName,
  required PlayerNight me,
  required PlayerNight partner,
  required SleepWindow? myWindow,
  required SleepWindow? partnerWindow,
  required DateTime now,
}) {
  final String label;
  var can = false;
  if (myWindow == null) {
    label = 'Set bedtime';
  } else if (me.wokeAt != null) {
    label = 'Good morning';
  } else if (me.checkedInAt != null) {
    label = 'Sleep well';
  } else if (checkInOpenAt(myWindow, now)) {
    label = 'Going to sleep';
    can = true;
  } else {
    label = 'Opens ${_hm((myWindow.bedtime - 120) % 1440)}';
  }
  return SleepWidgetContent(
    meLine: _status('You', me, myWindow),
    partnerLine: _status(partnerName.isEmpty ? 'Partner' : partnerName, partner, partnerWindow),
    buttonLabel: label,
    canCheckIn: can,
  );
}

/// The widget's line about your partner after a status push (app closed).
String partnerStatusLine(String name, String state, DateTime at) => switch (state) {
      'asleep' => '$name · asleep since ${_clock(at)}',
      'up' => '$name · up since ${_clock(at)}',
      _ => name,
    };
