import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase_providers.dart';
import '../pairing/pair_providers.dart';
import 'selfie.dart';
import 'selfie_repository.dart';
import 'selfie_widget.dart';

final selfieRepositoryProvider =
    Provider((ref) => SelfieRepository(ref.watch(firestoreProvider)));

final selfiesProvider = StreamProvider<List<Selfie>>((ref) async* {
  final pair = await ref.watch(pairProvider.future);
  if (pair == null) {
    yield const [];
    return;
  }
  yield* ref.watch(selfieRepositoryProvider).watchRecent(pair.id);
});

/// Selfies from the partner that have not been opened yet.
final unseenSelfiesProvider = Provider<int>((ref) {
  final uid = ref.watch(uidProvider).value;
  final all = ref.watch(selfiesProvider).value ?? const <Selfie>[];
  return all.where((s) => s.from != uid && s.seenAt == null).length;
});

/// Keeps the home-screen widget on the partner's latest selfie and deletes
/// your own selfies after a week.
final selfieSyncProvider = Provider<void>((ref) {
  ref.listen(selfiesProvider, (_, next) async {
    final all = next.value;
    final uid = ref.read(uidProvider).value;
    final pair = ref.read(pairProvider).value;
    if (all == null || uid == null || pair == null) return;
    final repo = ref.read(selfieRepositoryProvider);

    final latest = all.where((s) => s.from != uid).firstOrNull;
    if (latest != null) {
      try {
        await SelfieHomeWidget.update(
          bytes: latest.bytes,
          caption: captionFor(pair.nameOf(latest.from), latest.createdAt),
        );
      } catch (_) {
        // Widget support is best effort (for example in tests).
      }
    }
    for (final old in expiredOwn(all, uid, DateTime.now())) {
      try {
        await repo.delete(pair.id, old.id);
      } catch (_) {}
    }
  }, fireImmediately: true);
});
