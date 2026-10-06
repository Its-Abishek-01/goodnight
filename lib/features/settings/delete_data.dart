import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/firebase_providers.dart';
import '../../core/notifications.dart';
import '../alarm/alarm_scheduler.dart';
import '../blocking/blocker_channel.dart';
import '../pairing/pair.dart';
import '../pairing/pair_providers.dart';
import '../selfie/selfie_widget.dart';

/// Asks for confirmation, then deletes everything. Returns when done or
/// cancelled. The dialog sits above the app gate, so it stays open while the
/// gate switches screens underneath it.
Future<void> confirmDeleteData(BuildContext context, Pair pair) async {
  final go = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete all data?'),
      content: Text(
        pair.members.length > 1
            ? 'This ends the pact with ${pair.names.values.where((n) => n.isNotEmpty).join(' & ')} '
                'and permanently deletes everything you both stored: bedtimes, '
                'nights, streak, coupons and selfies. Your partner goes back to '
                'the pairing screen. This cannot be undone.'
            : 'This cancels your pair code and deletes your name. '
                'This cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Delete everything'),
        ),
      ],
    ),
  );
  if (go != true || !context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _DeletingDialog(pair: pair),
  );
}

class _DeletingDialog extends ConsumerStatefulWidget {
  const _DeletingDialog({required this.pair});

  final Pair pair;

  @override
  ConsumerState<_DeletingDialog> createState() => _DeletingDialogState();
}

class _DeletingDialogState extends ConsumerState<_DeletingDialog> {
  String? _error;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() => _error = null);
    try {
      final auth = ref.read(authProvider);
      final uid = auth.currentUser!.uid;
      await ref.read(pairRepositoryProvider).deletePair(widget.pair, uid);
      await _clearDevice();
      try {
        await auth.currentUser?.delete();
      } catch (_) {
        await auth.signOut();
      }
      ref.invalidate(uidProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    return AlertDialog(
      title: Text(error == null ? 'Deleting...' : 'Could not finish'),
      content: error == null
          ? const Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Expanded(child: Text('Removing your data. Keep the app open.')),
              ],
            )
          : Text('Check your internet and try again.\n\n$error'),
      actions: [
        if (error != null) ...[
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          FilledButton(onPressed: _run, child: const Text('Try again')),
        ],
      ],
    );
  }
}

/// Removes what this phone keeps on its own: alarms, reminders, the blocker
/// config, the widget photo and saved preferences. Each step is best effort.
Future<void> _clearDevice() async {
  Future<void> attempt(Future<void> Function() step) async {
    try {
      await step();
    } catch (_) {}
  }

  await attempt(AlarmScheduler.stopAll);
  await attempt(Notifications.cancelAll);
  await attempt(() => Blocker.saveConfig(enabled: false, bedtimeMin: 0, wakeMin: 0));
  await attempt(SelfieHomeWidget.clear);
  await attempt(() async => (await SharedPreferences.getInstance()).clear());
}
