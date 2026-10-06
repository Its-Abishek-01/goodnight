import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase_providers.dart';
import 'pair.dart';
import 'pair_repository.dart';

final pairRepositoryProvider =
    Provider((ref) => PairRepository(ref.watch(firestoreProvider)));

/// The signed-in user's pair, or null when they have not paired yet.
final pairProvider = StreamProvider<Pair?>((ref) async* {
  final uid = await ref.watch(uidProvider.future);
  final repo = ref.watch(pairRepositoryProvider);
  await for (final pairId in repo.watchPairId(uid)) {
    if (pairId == null) {
      yield null;
      continue;
    }
    yield* repo.watchPair(pairId);
  }
});
