import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase_providers.dart';
import '../../core/theme.dart';
import '../pairing/pair.dart';
import '../pairing/pair_providers.dart';
import '../profile/person_avatar.dart';
import '../profile/profile.dart';
import 'time_request.dart';

final timeRequestRepositoryProvider =
    Provider((ref) => TimeRequestRepository(ref.watch(firestoreProvider)));

final timeRequestsProvider = StreamProvider<List<TimeRequest>>((ref) async* {
  final pair = await ref.watch(pairProvider.future);
  if (pair == null) {
    yield const [];
    return;
  }
  yield* ref.watch(timeRequestRepositoryProvider).watchRecent(pair.id);
});

/// Tidies away your own old requests.
final timeRequestSyncProvider = Provider<void>((ref) {
  ref.listen(timeRequestsProvider, (_, next) async {
    final all = next.value;
    final uid = ref.read(uidProvider).value;
    final pair = ref.read(pairProvider).value;
    if (all == null || uid == null || pair == null) return;
    for (final old in expiredOwnRequests(all, uid, DateTime.now())) {
      try {
        await ref.read(timeRequestRepositoryProvider).delete(pair.id, old.id);
      } catch (_) {}
    }
  }, fireImmediately: true);
});

/// "Sam wants 10 more minutes": shown on Tonight while your partner's request
/// from the block screen waits for your answer.
class TimeRequestCard extends ConsumerWidget {
  const TimeRequestCard({super.key, required this.pair, required this.uid});

  final Pair pair;
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(timeRequestsProvider).value ?? const <TimeRequest>[];
    final r = incomingTimeRequest(all, uid, DateTime.now());
    if (r == null) return const SizedBox.shrink();
    final name = ref.watch(peopleProvider)[r.from]?.name ?? pair.nameOf(r.from);
    final repo = ref.read(timeRequestRepositoryProvider);
    final text = Theme.of(context).textTheme;

    Future<void> answer(bool give) async {
      HapticFeedback.selectionClick();
      try {
        await repo.answer(pair.id, r.id, give: give);
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Couldn't send your answer. Try again.")),
          );
        }
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.sky.surfaceHigh.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: context.sky.accent.withValues(alpha: 0.6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                PersonAvatar(uid: r.from, size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$name wants ${r.minutes} more minutes', style: text.titleSmall),
                      Text(
                        'Night mode paused their scrolling. You decide.',
                        style: text.bodySmall?.copyWith(color: context.sky.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => answer(false),
                    child: const Text('Not tonight'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => answer(true),
                    child: Text('Give ${r.minutes} min'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
