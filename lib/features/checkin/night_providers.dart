import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase_providers.dart';
import '../pairing/pair_providers.dart';
import 'night_log.dart';

final nightLogRepositoryProvider =
    Provider((ref) => NightLogRepository(ref.watch(firestoreProvider)));

/// Recent nights for the pair, newest first.
final nightsProvider = StreamProvider<List<Night>>((ref) async* {
  final pair = await ref.watch(pairProvider.future);
  if (pair == null) {
    yield const [];
    return;
  }
  yield* ref.watch(nightLogRepositoryProvider).watchRecent(pair.id);
});
