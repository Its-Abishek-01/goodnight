import 'package:cloud_firestore/cloud_firestore.dart';

import 'love_note.dart';

class LoveNoteException implements Exception {
  LoveNoteException(this.message);
  final String message;
  @override
  String toString() => message;
}

class LoveNoteRepository {
  LoveNoteRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String pairId) =>
      _db.collection('pairs/$pairId/loveNotes');

  /// The most recent notes from both of you, newest first.
  Stream<List<LoveNote>> watchRecent(String pairId) => _col(pairId)
      .orderBy('sentAt', descending: true)
      .limit(20)
      .snapshots()
      .map((s) => s.docs.map(LoveNote.fromDoc).toList());

  Future<void> send({
    required String pairId,
    required String uid,
    required String text,
  }) {
    final error = loveNoteError(text);
    if (error != null) throw LoveNoteException(error);
    return _col(pairId).add({
      'from': uid,
      'text': normalizeNote(text),
      'sentAt': FieldValue.serverTimestamp(),
      'seenAt': null,
    });
  }

  /// The read receipt: only the receiver can set this, and only once.
  Future<void> markSeen(String pairId, String id) =>
      _col(pairId).doc(id).update({'seenAt': FieldValue.serverTimestamp()});

  Future<void> delete(String pairId, String id) => _col(pairId).doc(id).delete();
}
