import 'package:cloud_firestore/cloud_firestore.dart';

import '../streak/streak.dart';
import 'coupon.dart';

class CouponRepository {
  CouponRepository(this._db);

  final FirebaseFirestore _db;

  Stream<List<Coupon>> watch(String pairId) => _db
      .collection('pairs/$pairId/coupons')
      .snapshots()
      .map((s) => s.docs.map(Coupon.fromDoc).toList());

  /// Grants each person a coupon for every milestone the streak has reached.
  /// A grant record is kept even after its coupons are used, so a streak can
  /// never earn the same coupon twice.
  Future<void> ensureGrants({
    required String pairId,
    required List<String> members,
    required String startKey,
    required int streak,
  }) async {
    for (final m in milestones.where((m) => m <= streak)) {
      final grantId = '${startKey}_$m';
      final grantRef = _db.doc('pairs/$pairId/grants/$grantId');
      await _db.runTransaction((tx) async {
        if ((await tx.get(grantRef)).exists) return;
        tx.set(grantRef, {
          'milestone': m,
          'startKey': startKey,
          'createdAt': FieldValue.serverTimestamp(),
        });
        for (final uid in members) {
          tx.set(_db.doc('pairs/$pairId/coupons/${grantId}_$uid'), {
            'holder': uid,
            'milestone': m,
            'grantId': grantId,
            'status': 'ready',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      });
    }
  }

  /// Uses a coupon. The partner is told and cannot refuse.
  Future<void> redeem(String pairId, String couponId, String title) =>
      _db.doc('pairs/$pairId/coupons/$couponId').update({
        'status': 'redeemed',
        'title': title,
        'redeemedAt': FieldValue.serverTimestamp(),
      });

  /// The partner has seen it and agreed. The coupon is gone for good.
  Future<void> acknowledge(String pairId, String couponId) =>
      _db.doc('pairs/$pairId/coupons/$couponId').delete();
}
