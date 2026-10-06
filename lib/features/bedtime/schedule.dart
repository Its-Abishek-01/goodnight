import 'package:cloud_firestore/cloud_firestore.dart';

/// A bedtime and wake time, stored as minutes since midnight.
class SleepWindow {
  const SleepWindow({required this.bedtime, required this.wake});

  final int bedtime;
  final int wake;

  /// Minutes between bedtime and wake time, crossing midnight if needed.
  int get sleepMinutes => (wake - bedtime) % 1440;

  factory SleepWindow.fromMap(Map<String, dynamic> m) => SleepWindow(
        bedtime: _parse(m['bedtime'] as String),
        wake: _parse(m['wake'] as String),
      );

  Map<String, String> toMap() => {'bedtime': _format(bedtime), 'wake': _format(wake)};

  static int _parse(String s) {
    final p = s.split(':');
    return int.parse(p[0]) * 60 + int.parse(p[1]);
  }

  static String _format(int m) =>
      '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';

  @override
  bool operator ==(Object other) =>
      other is SleepWindow && other.bedtime == bedtime && other.wake == wake;

  @override
  int get hashCode => Object.hash(bedtime, wake);
}

/// A bedtime waiting for approval. [by] is the uid of whoever proposed it,
/// so the other person is the one who can approve it.
class Proposal {
  const Proposal({required this.window, required this.by});

  final SleepWindow window;
  final String by;
}

/// One person's bedtime. [current] is the approved, locked window and stays
/// active while a change [proposal] is pending.
class Schedule {
  const Schedule({required this.owner, this.current, this.proposal});

  final String owner;
  final SleepWindow? current;
  final Proposal? proposal;

  factory Schedule.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    final cur = d['current'] as Map<String, dynamic>?;
    final prop = d['proposal'] as Map<String, dynamic>?;
    return Schedule(
      owner: doc.id,
      current: cur == null ? null : SleepWindow.fromMap(cur),
      proposal: prop == null
          ? null
          : Proposal(window: SleepWindow.fromMap(prop), by: prop['by'] as String),
    );
  }
}
