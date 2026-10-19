import 'package:cloud_firestore/cloud_firestore.dart';

import 'share.dart';

class ShareRepository {
  ShareRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String pairId) =>
      _db.collection('pairs/$pairId/shares');

  /// The most recent shares, newest first.
  Stream<List<Share>> watchRecent(String pairId) => _col(pairId)
      .orderBy('createdAt', descending: true)
      .limit(10)
      .snapshots()
      .map((s) => s.docs.map(Share.fromDoc).toList());

  Stream<Share?> watch(String pairId, String id) => _col(
    pairId,
  ).doc(id).snapshots().map((d) => d.exists ? Share.fromDoc(d) : null);

  /// The viewer asks to see the sharer's screen.
  Future<String> ask({
    required String pairId,
    required String viewer,
    required String sharer,
  }) async {
    final ref = await _col(pairId).add({
      'sharer': sharer,
      'viewer': viewer,
      'by': viewer,
      'status': ShareStatus.asked.name,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// The sharer offers their screen with a ready offer.
  Future<String> offer({
    required String pairId,
    required String sharer,
    required String viewer,
    required Map<String, dynamic> offer,
  }) async {
    final ref = await _col(pairId).add({
      'sharer': sharer,
      'viewer': viewer,
      'by': sharer,
      'status': ShareStatus.offered.name,
      'offer': offer,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// The sharer answers a request with their offer.
  Future<void> answerRequest(
    String pairId,
    String id,
    Map<String, dynamic> offer,
  ) => _col(
    pairId,
  ).doc(id).update({'offer': offer, 'status': ShareStatus.offered.name});

  /// The viewer joins with their answer.
  Future<void> join(String pairId, String id, Map<String, dynamic> answer) =>
      _col(pairId).doc(id).update({
        'answer': answer,
        'status': ShareStatus.live.name,
        'startedAt': FieldValue.serverTimestamp(),
      });

  Future<void> addIce(
    String pairId,
    String id, {
    required bool sharer,
    required IceCandidate c,
  }) => _col(pairId).doc(id).update({
    sharer ? 'sharerIce' : 'viewerIce': FieldValue.arrayUnion([c.toMap()]),
  });

  Future<void> setStatus(String pairId, String id, ShareStatus status) =>
      _col(pairId).doc(id).update({
        'status': status.name,
        if (status == ShareStatus.ended || status == ShareStatus.declined)
          'endedAt': FieldValue.serverTimestamp(),
      });

  Future<void> delete(String pairId, String id) =>
      _col(pairId).doc(id).delete();
}
