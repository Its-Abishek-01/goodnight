import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../pairing/pair.dart';
import '../streak/streak_providers.dart';
import 'coupon.dart';
import 'coupon_providers.dart';
import 'coupon_repository.dart';

/// Coupons earned by streak. Using one cannot be refused, and it is deleted
/// once the partner has seen it.
class CouponsScreen extends ConsumerWidget {
  const CouponsScreen({super.key, required this.pair, required this.uid});

  final Pair pair;
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coupons = ref.watch(couponsProvider).value ?? const <Coupon>[];
    final streak = ref.watch(streakProvider);
    final repo = ref.read(couponRepositoryProvider);
    final partnerName = pair.nameOf(pair.partnerUid(uid) ?? '');

    final toAcknowledge = coupons
        .where((c) => c.status == CouponStatus.redeemed && c.holder != uid)
        .toList();
    final mine = coupons
        .where((c) => c.status == CouponStatus.ready && c.holder == uid)
        .toList();
    final waiting = coupons
        .where((c) => c.status == CouponStatus.redeemed && c.holder == uid)
        .toList();
    final next = nextMilestone(streak.count);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Coupons', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          next == null
              ? 'You have earned every coupon tier. 🎉'
              : 'Next coupon at $next nights. Current streak: ${streak.count}.',
        ),
        const SizedBox(height: 12),
        for (final c in toAcknowledge)
          Card(
            color: Theme.of(context).colorScheme.tertiaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('💌 $partnerName used a coupon',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text('"${c.title}" - no questions asked.'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => repo.acknowledge(pair.id, c.id),
                    child: const Text('Done, it is yours ✓'),
                  ),
                ],
              ),
            ),
          ),
        if (mine.isEmpty && toAcknowledge.isEmpty && waiting.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'No coupons yet. Keep the streak going and you will earn one for each other.',
            ),
          ),
        for (final c in mine)
          Card(
            child: ListTile(
              leading: const Text('🎟️', style: TextStyle(fontSize: 28)),
              title: Text('${c.milestone}-night streak coupon'),
              subtitle: Text('Use it once on $partnerName. They cannot say no.'),
              trailing: FilledButton(
                onPressed: () => _use(context, repo, c),
                child: const Text('Use'),
              ),
            ),
          ),
        for (final c in waiting)
          Card(
            child: ListTile(
              leading: const Text('⏳', style: TextStyle(fontSize: 28)),
              title: Text('"${c.title}"'),
              subtitle: Text('Used. Waiting for $partnerName to confirm.'),
            ),
          ),
      ],
    );
  }

  Future<void> _use(BuildContext context, CouponRepository repo, Coupon c) async {
    final title = await showDialog<String>(
      context: context,
      builder: (_) => const _UseDialog(),
    );
    if (title == null || title.trim().isEmpty) return;
    await repo.redeem(pair.id, c.id, title.trim());
  }
}

class _UseDialog extends StatefulWidget {
  const _UseDialog();

  @override
  State<_UseDialog> createState() => _UseDialogState();
}

class _UseDialogState extends State<_UseDialog> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('What is it for?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final idea in couponIdeas)
                  ActionChip(
                    label: Text(idea),
                    onPressed: () => setState(() => _text.text = idea),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _text,
              decoration: const InputDecoration(
                labelText: 'Or write your own',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            const Text('This can only be used once.', style: TextStyle(fontSize: 12)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(context, _text.text),
          child: const Text('Use coupon'),
        ),
      ],
    );
  }
}
