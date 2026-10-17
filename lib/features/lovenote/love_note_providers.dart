import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase_providers.dart';
import '../pairing/pair_providers.dart';
import 'love_note.dart';
import 'love_note_repository.dart';

final loveNoteRepositoryProvider =
    Provider((ref) => LoveNoteRepository(ref.watch(firestoreProvider)));

/// Recent notes between the two of you, newest first.
final loveNotesProvider = StreamProvider<List<LoveNote>>((ref) async* {
  final pair = await ref.watch(pairProvider.future);
  if (pair == null) {
    yield const [];
    return;
  }
  yield* ref.watch(loveNoteRepositoryProvider).watchRecent(pair.id);
});

/// The most recent note you sent, so the composer can show its read receipt.
final lastSentNoteProvider = Provider<LoveNote?>((ref) {
  final uid = ref.watch(uidProvider).value;
  final all = ref.watch(loveNotesProvider).value ?? const <LoveNote>[];
  if (uid == null) return null;
  return latestSentBy(all, uid);
});

/// Holds the incoming note to show full-screen right now, or null. It latches
/// onto the newest unseen note from your partner and is cleared when you close
/// it, so marking it seen does not make it vanish before you have read it.
class LoveNoteInbox extends Notifier<LoveNote?> {
  final _handled = <String>{};

  @override
  LoveNote? build() {
    ref.listen(loveNotesProvider, (_, next) {
      final uid = ref.read(uidProvider).value;
      final all = next.value;
      if (uid == null || all == null) return;
      final note = latestIncomingUnseen(all, uid);
      if (note == null || _handled.contains(note.id)) return;
      if (state != null) return; // one at a time; the rest wait their turn
      state = note;
    }, fireImmediately: true);
    return null;
  }

  /// Close the note that is showing, and remember not to show it again even
  /// before Firestore confirms the read receipt.
  void dismiss() {
    final cur = state;
    if (cur != null) _handled.add(cur.id);
    state = null;
  }
}

final loveNoteInboxProvider =
    NotifierProvider<LoveNoteInbox, LoveNote?>(LoveNoteInbox.new);

/// Tidies away your own notes once they are a week old.
final loveNoteSyncProvider = Provider<void>((ref) {
  ref.listen(loveNotesProvider, (_, next) async {
    final all = next.value;
    final uid = ref.read(uidProvider).value;
    final pair = ref.read(pairProvider).value;
    if (all == null || uid == null || pair == null) return;
    final repo = ref.read(loveNoteRepositoryProvider);
    for (final old in expiredOwnNotes(all, uid, DateTime.now())) {
      try {
        await repo.delete(pair.id, old.id);
      } catch (_) {}
    }
  }, fireImmediately: true);
});
