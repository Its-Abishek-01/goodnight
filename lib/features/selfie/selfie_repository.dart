import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'selfie.dart';

class SelfieException implements Exception {
  SelfieException(this.message);
  final String message;
  @override
  String toString() => message;
}

class SelfieRepository {
  SelfieRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String pairId) =>
      _db.collection('pairs/$pairId/selfies');

  /// The most recent selfies from both of you, newest first.
  Stream<List<Selfie>> watchRecent(String pairId) => _col(pairId)
      .orderBy('createdAt', descending: true)
      .limit(20)
      .snapshots()
      .map((s) => s.docs.map(Selfie.fromDoc).toList());

  Future<void> send({
    required String pairId,
    required String uid,
    required Uint8List bytes,
  }) {
    if (bytes.length > selfieMaxBytes) {
      throw SelfieException('That photo is too large. Try again.');
    }
    return _col(pairId).add({
      'from': uid,
      'image': Blob(bytes),
      'createdAt': FieldValue.serverTimestamp(),
      'seenAt': null,
    });
  }

  /// The read receipt: only the receiver can set this, and only once.
  Future<void> markSeen(String pairId, String id) =>
      _col(pairId).doc(id).update({'seenAt': FieldValue.serverTimestamp()});

  Future<void> delete(String pairId, String id) => _col(pairId).doc(id).delete();
}
