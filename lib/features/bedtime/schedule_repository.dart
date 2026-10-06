import 'package:cloud_firestore/cloud_firestore.dart';

import 'schedule.dart';

class ScheduleRepository {
  ScheduleRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _ref(String pairId, String owner) =>
      _db.doc('pairs/$pairId/schedules/$owner');

  /// Both schedules of the pair, keyed by owner uid.
  Stream<Map<String, Schedule>> watch(String pairId) => _db
      .collection('pairs/$pairId/schedules')
      .snapshots()
      .map((s) => {for (final d in s.docs) d.id: Schedule.fromDoc(d)});

  /// Proposes (or counter-proposes) a window for [owner]. The approved
  /// window, if any, stays active until the other person approves.
  Future<void> propose({
    required String pairId,
    required String owner,
    required String by,
    required SleepWindow window,
  }) {
    final ref = _ref(pairId, owner);
    return _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      tx.set(ref, {
        'current': snap.data()?['current'],
        'proposal': {...window.toMap(), 'by': by},
      });
    });
  }

  /// Approves the pending proposal, which locks it as the current window.
  Future<void> approve({required String pairId, required String owner}) {
    final ref = _ref(pairId, owner);
    return _db.runTransaction((tx) async {
      final proposal = (await tx.get(ref)).data()?['proposal'] as Map<String, dynamic>?;
      if (proposal == null) return;
      tx.set(ref, {
        'current': {'bedtime': proposal['bedtime'], 'wake': proposal['wake']},
        'proposal': null,
        'approvedAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
