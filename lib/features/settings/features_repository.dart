import 'package:cloud_firestore/cloud_firestore.dart';

import 'features.dart';

/// Stored under `pairs/{pairId}/features`: one doc per person (keyed by uid)
/// and one `shared` doc for the couple.
class FeaturesRepository {
  FeaturesRepository(this._db);

  final FirebaseFirestore _db;

  static const sharedId = 'shared';

  CollectionReference<Map<String, dynamic>> _col(String pairId) =>
      _db.collection('pairs/$pairId/features');

  /// Each person's features, keyed by uid. Missing people have everything on.
  Stream<Map<String, PersonalFeatures>> watchPersonal(String pairId) =>
      _col(pairId).snapshots().map(
        (s) => {
          for (final d in s.docs)
            if (d.id != sharedId) d.id: PersonalFeatures.fromMap(d.data()),
        },
      );

  Stream<SharedSettings> watchShared(String pairId) => _col(
    pairId,
  ).doc(sharedId).snapshots().map((s) => SharedSettings.fromMap(s.data()));

  Future<void> setPersonal(String pairId, String uid, PersonalFeatures f) =>
      _col(pairId).doc(uid).set(f.toMap());

  /// Proposes new shared features. The approved ones stay active until the
  /// other person approves.
  Future<void> proposeShared({
    required String pairId,
    required String by,
    required SharedFeatures features,
  }) {
    final ref = _col(pairId).doc(sharedId);
    return _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      tx.set(ref, {
        'current': snap.data()?['current'],
        'proposal': {...features.toMap(), 'by': by},
      });
    });
  }

  Future<void> approveShared(String pairId) {
    final ref = _col(pairId).doc(sharedId);
    return _db.runTransaction((tx) async {
      final proposal =
          (await tx.get(ref)).data()?['proposal'] as Map<String, dynamic>?;
      if (proposal == null) return;
      tx.set(ref, {
        'current': SharedFeatures.fromMap(proposal).toMap(),
        'proposal': null,
      });
    });
  }

  /// Clears a pending proposal: the proposer withdraws it or the partner
  /// declines it.
  Future<void> withdrawShared(String pairId) {
    final ref = _col(pairId).doc(sharedId);
    return _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      tx.set(ref, {'current': snap.data()?['current'], 'proposal': null});
    });
  }
}
