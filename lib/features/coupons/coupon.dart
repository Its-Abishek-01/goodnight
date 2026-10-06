import 'package:cloud_firestore/cloud_firestore.dart';

import '../streak/streak.dart';

enum CouponStatus { ready, redeemed }

/// A single-use "no questions asked" coupon. [holder] earned it and is the
/// only one who can use it, on the other person.
class Coupon {
  const Coupon({
    required this.id,
    required this.holder,
    required this.milestone,
    required this.status,
    this.title,
  });

  final String id;
  final String holder;
  final int milestone;
  final CouponStatus status;
  final String? title;

  factory Coupon.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return Coupon(
      id: doc.id,
      holder: d['holder'] as String,
      milestone: (d['milestone'] as num).toInt(),
      status: d['status'] == 'redeemed' ? CouponStatus.redeemed : CouponStatus.ready,
      title: d['title'] as String?,
    );
  }
}

/// Ideas offered when using a coupon. Free text is allowed too.
const couponIdeas = [
  'Pick tonight\'s movie 🎬',
  'A favour, no questions asked',
  'Breakfast treat 🍳',
  'Skip one chore',
  'A long hug 🤗',
  'A surprise date 💌',
];

/// The next milestone above [streak], or null if all are earned.
int? nextMilestone(int streak) {
  for (final m in milestones) {
    if (m > streak) return m;
  }
  return null;
}
