import 'package:cloud_firestore/cloud_firestore.dart';

/// A short, sudden message one partner sends the other. It arrives full-screen
/// (and as a push when the Cloud Functions are deployed), and the sender sees a
/// read receipt once it has been seen. Kept small and private to the two of you.
const loveNoteMaxLen = 200;
const loveNoteKeepDays = 7;

/// One-tap things to send without typing.
const loveNotePresets = [
  'I love you ❤️',
  'Thinking of you 🌙',
  'Goodnight, sleep tight',
  'Miss you',
  'Proud of you',
];

class LoveNote {
  const LoveNote({
    required this.id,
    required this.from,
    required this.text,
    required this.sentAt,
    this.seenAt,
  });

  final String id;
  final String from;
  final String text;
  final DateTime sentAt;

  /// Set when the partner sees it full-screen (the read receipt).
  final DateTime? seenAt;

  factory LoveNote.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return LoveNote(
      id: doc.id,
      from: d['from'] as String,
      text: d['text'] as String? ?? '',
      sentAt: (d['sentAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      seenAt: (d['seenAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// Trim and tidy a note before sending.
String normalizeNote(String text) => text.trim();

/// Why this note cannot be sent, or null if it is fine.
String? loveNoteError(String text) {
  final t = normalizeNote(text);
  if (t.isEmpty) return 'Write something first.';
  if (t.length > loveNoteMaxLen) return 'Keep it under $loveNoteMaxLen characters.';
  return null;
}

/// The newest note from the partner that [uid] has not seen yet. [all] is
/// newest-first.
LoveNote? latestIncomingUnseen(List<LoveNote> all, String uid) {
  for (final n in all) {
    if (n.from != uid && n.seenAt == null) return n;
  }
  return null;
}

/// The newest note [uid] has sent, for showing its read receipt. Newest-first.
LoveNote? latestSentBy(List<LoveNote> all, String uid) {
  for (final n in all) {
    if (n.from == uid) return n;
  }
  return null;
}

/// Own notes old enough to tidy away, so the collection stays small.
List<LoveNote> expiredOwnNotes(List<LoveNote> all, String uid, DateTime now) => all
    .where((n) =>
        n.from == uid &&
        now.difference(n.sentAt) > const Duration(days: loveNoteKeepDays))
    .toList();
