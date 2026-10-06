import '../bedtime/schedule.dart';
import '../checkin/night_log.dart';

/// A night is good when BOTH people checked in on time and woke up properly.
const maxGoodSnoozes = 3;
const checkInGraceMinutes = 15;
const checkInEarlyMinutes = 240;

/// Streak lengths that earn a coupon for each person.
const milestones = [7, 14, 30, 60];

String previousKey(String key) {
  final d = DateTime.parse(key);
  return formatNightKey(DateTime(d.year, d.month, d.day - 1));
}

String weekStartKey(String key) {
  final d = DateTime.parse(key);
  return formatNightKey(DateTime(d.year, d.month, d.day - (d.weekday - 1)));
}

/// Checked in no later than [checkInGraceMinutes] after bedtime (and not
/// absurdly early, which would be a check-in made at the wrong time of day).
bool goodBedtime(PlayerNight p, SleepWindow? w) {
  final at = p.checkedInAt;
  if (at == null) return false;
  if (w == null) return true;
  final minute = at.hour * 60 + at.minute;
  final d = ((minute - w.bedtime + 720) % 1440) - 720;
  return d <= checkInGraceMinutes && d >= -checkInEarlyMinutes;
}

/// Woke up with few enough snoozes. Someone without the alarm that night has
/// no wake-up to judge, so their morning always counts.
bool goodMorning(PlayerNight p) =>
    !p.alarm || (p.wokeAt != null && p.snoozes <= maxGoodSnoozes);

/// Nothing more to wait for from this person tonight: they confirmed they are
/// up, or they checked in without the alarm.
bool morningDone(PlayerNight p) =>
    p.wokeAt != null || (!p.alarm && p.checkedInAt != null);

bool isGoodNight(
  Night n,
  Map<String, SleepWindow> windows,
  Iterable<String> members,
) =>
    members.every((m) {
      final p = n.playerOf(m);
      return goodBedtime(p, windows[m]) && goodMorning(p);
    });

/// True once everyone is done for the night (see [morningDone]), or the night
/// is in the past.
bool isComplete(Night n, Iterable<String> members, String currentKey) =>
    n.key.compareTo(currentKey) < 0 ||
    members.every((m) => morningDone(n.playerOf(m)));

class StreakInfo {
  const StreakInfo(this.count, this.startKey);

  static const none = StreakInfo(0, null);

  final int count;

  /// The first night of the current streak. Used to give each milestone a
  /// stable id so a coupon is only ever granted once.
  final String? startKey;
}

/// Consecutive good nights ending at the latest finished night. A forgiven
/// night keeps the streak alive without adding to it.
StreakInfo computeStreak(
  List<Night> nights,
  Map<String, SleepWindow> windows,
  List<String> members,
  String currentKey,
) {
  final byKey = {for (final n in nights) n.key: n};
  var count = 0;
  String? start;

  final cur = byKey[currentKey];
  if (cur != null && members.every((m) => morningDone(cur.playerOf(m)))) {
    if (isGoodNight(cur, windows, members)) {
      count++;
      start = currentKey;
    } else if (!cur.forgiven) {
      return StreakInfo.none;
    } else {
      start = currentKey;
    }
  }

  var cursor = previousKey(currentKey);
  while (true) {
    final n = byKey[cursor];
    if (n == null) break;
    final good = isGoodNight(n, windows, members);
    if (!good && !n.forgiven) break;
    if (good) count++;
    start = cursor;
    cursor = previousKey(cursor);
  }
  return count == 0 ? StreakInfo.none : StreakInfo(count, start);
}

/// Whether a forgiveness is still available in the week of [key].
bool canForgiveInWeek(List<Night> nights, String key) {
  final week = weekStartKey(key);
  return !nights.any((n) => n.forgiven && weekStartKey(n.key) == week);
}
