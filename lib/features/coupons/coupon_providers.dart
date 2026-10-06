import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase_providers.dart';
import '../pairing/pair_providers.dart';
import '../streak/streak_providers.dart';
import 'coupon.dart';
import 'coupon_repository.dart';

final couponRepositoryProvider =
    Provider((ref) => CouponRepository(ref.watch(firestoreProvider)));

final couponsProvider = StreamProvider<List<Coupon>>((ref) async* {
  final pair = await ref.watch(pairProvider.future);
  if (pair == null) {
    yield const [];
    return;
  }
  yield* ref.watch(couponRepositoryProvider).watch(pair.id);
});

/// Creates coupons whenever the streak reaches a milestone.
final couponSyncProvider = Provider<void>((ref) {
  final ensured = <String>{};
  ref.listen(streakProvider, (_, streak) async {
    final pair = ref.read(pairProvider).value;
    final start = streak.startKey;
    if (pair == null || start == null || streak.count == 0) return;
    final marker = '$start/${streak.count}';
    if (!ensured.add(marker)) return;
    try {
      await ref.read(couponRepositoryProvider).ensureGrants(
            pairId: pair.id,
            members: pair.members,
            startKey: start,
            streak: streak.count,
          );
    } catch (_) {
      ensured.remove(marker);
    }
  }, fireImmediately: true);
});
