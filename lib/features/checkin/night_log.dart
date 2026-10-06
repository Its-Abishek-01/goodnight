import 'package:cloud_firestore/cloud_firestore.dart';

String _pad(int n) => n.toString().padLeft(2, '0');

/// The key of the night that [now] belongs to. A night starts at bedtime on
/// day D and ends the next morning, so shifting by 12 hours keeps both
/// 23:00 on D and 07:00 on D+1 inside night D.
String nightKey(DateTime now) =>
    formatNightKey(now.subtract(const Duration(hours: 12)));

String formatNightKey(DateTime d) => '${d.year}-${_pad(d.month)}-${_pad(d.day)}';

DateTime nightKeyToDate(String key) => DateTime.parse(key);

/// One person's record for one night.
class PlayerNight {
  const PlayerNight({
    this.checkedInAt,
    this.wokeAt,
    this.snoozes = 0,
    this.blocks = 0,
    this.usageMinutes = 0,
  });

  final DateTime? checkedInAt;
  final DateTime? wokeAt;
  final int snoozes;
  final int blocks;
  final int usageMinutes;

  factory PlayerNight.fromMap(Map<String, dynamic> m) => PlayerNight(
        checkedInAt: (m['checkedInAt'] as Timestamp?)?.toDate(),
        wokeAt: (m['wokeAt'] as Timestamp?)?.toDate(),
        snoozes: (m['snoozes'] as num?)?.toInt() ?? 0,
        blocks: (m['blocks'] as num?)?.toInt() ?? 0,
        usageMinutes: (m['usageMinutes'] as num?)?.toInt() ?? 0,
      );
}

class Night {
  const Night({
    required this.key,
    required this.players,
    this.forgiveBy,
    this.forgiven = false,
  });

  final String key;
  final Map<String, PlayerNight> players;

  /// Uid of whoever asked to forgive this night, and whether the other agreed.
  final String? forgiveBy;
  final bool forgiven;

  factory Night.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final raw = (d['players'] as Map?) ?? {};
    return Night(
      key: doc.id,
      players: {
        for (final e in raw.entries)
          e.key as String:
              PlayerNight.fromMap(Map<String, dynamic>.from(e.value as Map)),
      },
      forgiveBy: d['forgiveBy'] as String?,
      forgiven: d['forgiven'] as bool? ?? false,
    );
  }

  PlayerNight playerOf(String uid) => players[uid] ?? const PlayerNight();
}

class NightLogRepository {
  NightLogRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _ref(String pairId, String key) =>
      _db.doc('pairs/$pairId/nights/$key');

  /// The most recent nights, newest first.
  Stream<List<Night>> watchRecent(String pairId, {int limit = 60}) => _db
      .collection('pairs/$pairId/nights')
      .orderBy(FieldPath.documentId, descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => s.docs.map(Night.fromDoc).toList());

  Future<void> _mergePlayer(
    String pairId,
    String uid,
    DateTime now,
    Map<String, dynamic> fields,
  ) {
    return _ref(pairId, nightKey(now)).set({
      'players': {uid: fields},
    }, SetOptions(merge: true));
  }

  Future<void> checkIn(String pairId, String uid, DateTime now) => _mergePlayer(
        pairId,
        uid,
        now,
        {'checkedInAt': Timestamp.fromDate(now)},
      );

  Future<void> recordSnooze(String pairId, String uid, DateTime now) =>
      _mergePlayer(pairId, uid, now, {'snoozes': FieldValue.increment(1)});

  Future<void> recordWake(
    String pairId,
    String uid,
    DateTime now, {
    required String key,
  }) {
    return _ref(pairId, key).set({
      'players': {
        uid: {'wokeAt': Timestamp.fromDate(now)},
      },
    }, SetOptions(merge: true));
  }

  Future<void> recordBlocks(
    String pairId,
    String uid,
    String key, {
    required int blocks,
    required int usageMinutes,
  }) {
    return _ref(pairId, key).set({
      'players': {
        uid: {'blocks': blocks, 'usageMinutes': usageMinutes},
      },
    }, SetOptions(merge: true));
  }

  Future<void> proposeForgive(String pairId, String key, String uid) =>
      _ref(pairId, key).set(
        {'forgiveBy': uid, 'forgiven': false},
        SetOptions(merge: true),
      );

  Future<void> approveForgive(String pairId, String key) =>
      _ref(pairId, key).set({'forgiven': true}, SetOptions(merge: true));
}
