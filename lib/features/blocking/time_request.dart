import 'package:cloud_firestore/cloud_firestore.dart';

/// A request for extra minutes, sent from the night-mode block screen
/// (`TimeRequests.kt`). The partner gives the time or says no.
class TimeRequest {
  const TimeRequest({
    required this.id,
    required this.from,
    required this.minutes,
    required this.status,
    this.createdAt,
  });

  final String id;
  final String from;
  final int minutes;

  /// pending, approved or declined.
  final String status;
  final DateTime? createdAt;

  bool get pending => status == 'pending';

  factory TimeRequest.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return TimeRequest(
      id: doc.id,
      from: d['from'] as String? ?? '',
      minutes: (d['minutes'] as num?)?.toInt() ?? 0,
      status: d['status'] as String? ?? 'pending',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// The phone gives up waiting after 20 minutes, so older requests are moot.
const timeRequestExpiry = Duration(minutes: 20);

/// The newest request from your partner still waiting for your answer.
TimeRequest? incomingTimeRequest(List<TimeRequest> all, String viewer, DateTime now) {
  for (final r in all) {
    if (r.from == viewer || !r.pending) continue;
    final at = r.createdAt;
    if (at == null || now.difference(at) > timeRequestExpiry) continue;
    return r;
  }
  return null;
}

/// Your own requests older than two days, to tidy away.
Iterable<TimeRequest> expiredOwnRequests(List<TimeRequest> all, String viewer, DateTime now) =>
    all.where((r) =>
        r.from == viewer && r.createdAt != null && now.difference(r.createdAt!) > const Duration(days: 2));

class TimeRequestRepository {
  TimeRequestRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String pairId) =>
      _db.collection('pairs/$pairId/timeRequests');

  /// Recent requests from both of you, newest first.
  Stream<List<TimeRequest>> watchRecent(String pairId) => _col(pairId)
      .orderBy('createdAt', descending: true)
      .limit(20)
      .snapshots()
      .map((s) => s.docs.map(TimeRequest.fromDoc).toList());

  /// Only the partner of the person who asked can answer, once.
  Future<void> answer(String pairId, String id, {required bool give}) => _col(pairId)
      .doc(id)
      .update({'status': give ? 'approved' : 'declined', 'decidedAt': FieldValue.serverTimestamp()});

  Future<void> delete(String pairId, String id) => _col(pairId).doc(id).delete();
}
