import 'package:cloud_firestore/cloud_firestore.dart';

enum PairStatus { waiting, active }

class Pair {
  const Pair({
    required this.id,
    required this.code,
    required this.members,
    required this.names,
    required this.status,
  });

  final String id;
  final String code;
  final List<String> members;
  final Map<String, String> names;
  final PairStatus status;

  factory Pair.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return Pair(
      id: doc.id,
      code: d['code'] as String? ?? '',
      members: List<String>.from(d['members'] as List),
      names: Map<String, String>.from(d['names'] as Map),
      status: d['status'] == 'active' ? PairStatus.active : PairStatus.waiting,
    );
  }

  String? partnerUid(String me) {
    for (final m in members) {
      if (m != me) return m;
    }
    return null;
  }

  String nameOf(String uid) => names[uid] ?? '';
}
