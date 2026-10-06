import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'pair.dart';

class PairException implements Exception {
  PairException(this.message);
  final String message;
  @override
  String toString() => message;
}

class PairRepository {
  PairRepository(this._db);

  final FirebaseFirestore _db;

  // No 0/O, 1/I/L so codes are easy to read out loud.
  static const _alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  static const codeLength = 6;

  static String generateCode([Random? random]) {
    final r = random ?? Random.secure();
    return List.generate(
      codeLength,
      (_) => _alphabet[r.nextInt(_alphabet.length)],
    ).join();
  }

  static String normalizeCode(String input) =>
      input.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  Stream<String?> watchPairId(String uid) => _db
      .doc('users/$uid')
      .snapshots()
      .map((s) => s.data()?['pairId'] as String?);

  Stream<Pair?> watchPair(String pairId) => _db
      .doc('pairs/$pairId')
      .snapshots()
      .map((s) => s.exists ? Pair.fromDoc(s) : null);

  /// Creates a waiting pair and returns its join code.
  Future<String> createPair({required String uid, required String name}) async {
    final code = generateCode();
    await _db.runTransaction((tx) async {
      final codeRef = _db.doc('pairCodes/$code');
      if ((await tx.get(codeRef)).exists) {
        throw PairException('Please try again.');
      }
      final pairRef = _db.collection('pairs').doc();
      tx.set(pairRef, {
        'code': code,
        'members': [uid],
        'names': {uid: name},
        'status': 'waiting',
        'createdAt': FieldValue.serverTimestamp(),
      });
      tx.set(codeRef, {'pairId': pairRef.id});
      tx.set(_db.doc('users/$uid'), {'name': name, 'pairId': pairRef.id});
    });
    return code;
  }

  /// Joins the pair that owns [rawCode]. Codes are single use.
  Future<void> joinPair({
    required String uid,
    required String name,
    required String rawCode,
  }) async {
    final code = normalizeCode(rawCode);
    if (code.length != codeLength) {
      throw PairException('Enter the $codeLength-character code.');
    }
    await _db.runTransaction((tx) async {
      final codeRef = _db.doc('pairCodes/$code');
      final codeSnap = await tx.get(codeRef);
      if (!codeSnap.exists) {
        throw PairException('That code was not found or was already used.');
      }
      final pairRef = _db.doc('pairs/${codeSnap.data()!['pairId']}');
      final pairSnap = await tx.get(pairRef);
      final members = List<String>.from(pairSnap.data()?['members'] ?? []);
      if (members.contains(uid)) {
        throw PairException('This is your own code. Share it with your partner.');
      }
      if (members.length != 1) {
        throw PairException('That code was not found or was already used.');
      }
      tx.update(pairRef, {
        'members': [...members, uid],
        'names.$uid': name,
        'status': 'active',
      });
      tx.delete(codeRef);
      tx.set(_db.doc('users/$uid'), {'name': name, 'pairId': pairRef.id});
    });
  }
}
