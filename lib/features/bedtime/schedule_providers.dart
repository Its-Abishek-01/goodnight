import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase_providers.dart';
import '../pairing/pair_providers.dart';
import 'schedule.dart';
import 'schedule_repository.dart';

final scheduleRepositoryProvider =
    Provider((ref) => ScheduleRepository(ref.watch(firestoreProvider)));

/// Both partners' schedules, keyed by owner uid.
final schedulesProvider = StreamProvider<Map<String, Schedule>>((ref) async* {
  final pair = await ref.watch(pairProvider.future);
  if (pair == null) {
    yield {};
    return;
  }
  yield* ref.watch(scheduleRepositoryProvider).watch(pair.id);
});
