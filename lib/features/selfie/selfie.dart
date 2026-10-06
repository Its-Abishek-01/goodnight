import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

const selfieDailyLimit = 5;
const selfieKeepDays = 7;
const selfieMaxBytes = 700000;

/// A small private photo one partner sends the other. The compressed image
/// lives inside the Firestore document, so only the two of them can read it.
class Selfie {
  const Selfie({
    required this.id,
    required this.from,
    required this.bytes,
    required this.createdAt,
    this.seenAt,
  });

  final String id;
  final String from;
  final Uint8List bytes;
  final DateTime createdAt;

  /// Set when the partner opens it in the app (the read receipt).
  final DateTime? seenAt;

  factory Selfie.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return Selfie(
      id: doc.id,
      from: d['from'] as String,
      bytes: (d['image'] as Blob).bytes,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      seenAt: (d['seenAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// How many selfies [uid] has sent since local midnight [now].
int sentToday(List<Selfie> all, String uid, DateTime now) {
  final start = DateTime(now.year, now.month, now.day);
  return all.where((s) => s.from == uid && !s.createdAt.isBefore(start)).length;
}

/// Own selfies old enough to be deleted.
List<Selfie> expiredOwn(List<Selfie> all, String uid, DateTime now) => all
    .where((s) =>
        s.from == uid &&
        now.difference(s.createdAt) > const Duration(days: selfieKeepDays))
    .toList();

/// "7:42 AM" without needing a BuildContext.
String clockLabel(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m ${t.hour < 12 ? 'AM' : 'PM'}';
}

String captionFor(String name, DateTime t) => '$name · ${clockLabel(t)}';
