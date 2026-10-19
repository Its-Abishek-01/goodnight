import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/theme.dart';
import 'backup_code.dart';
import 'backup_service.dart';

/// "Account backup" on the Us tab: make a code that brings this account back
/// on a new phone or after a reinstall.
class BackupCard extends ConsumerStatefulWidget {
  const BackupCard({super.key});

  @override
  ConsumerState<BackupCard> createState() => _BackupCardState();
}

class _BackupCardState extends ConsumerState<BackupCard> {
  bool _busy = false;
  String? _saved;

  @override
  void initState() {
    super.initState();
    ref.read(backupServiceProvider).savedCode().then((c) {
      if (mounted) setState(() => _saved = c);
    });
  }

  Future<void> _create({required bool replace}) async {
    if (replace) {
      final go = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Make a new code?'),
          content: const Text('Your old backup code stops working. Save the new one instead.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Make a new code')),
          ],
        ),
      );
      if (go != true) return;
    }
    setState(() => _busy = true);
    try {
      final code = await ref.read(backupServiceProvider).create();
      if (!mounted) return;
      setState(() => _saved = code);
      await _show(code);
    } on BackupException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _show(String code) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => BackupCodeScreen(code: code)),
      );

  @override
  Widget build(BuildContext context) {
    final backedUp = ref.read(backupServiceProvider).isBackedUp;
    final text = Theme.of(context).textTheme;
    final sky = context.sky;
    return SizedBox(
      width: double.infinity,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.key_rounded, color: sky.accent),
                  const SizedBox(width: 8),
                  Text('Account backup', style: text.titleSmall),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'If you change phones or reinstall GoodNight, a backup code brings back '
                'your pair, streak and history.',
                style: text.bodySmall?.copyWith(color: sky.muted),
              ),
              const SizedBox(height: 8),
              Text(
                backedUp ? 'Backed up ✓' : 'Not backed up yet',
                style: text.labelLarge?.copyWith(
                  color: backedUp ? sky.accent : Theme.of(context).colorScheme.error,
                ),
              ),
              const SizedBox(height: 10),
              if (!backedUp)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _busy ? null : () => _create(replace: false),
                    child: const Text('Create my backup code'),
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (_saved != null)
                      FilledButton(onPressed: () => _show(_saved!), child: const Text('Show my code')),
                    OutlinedButton(
                      onPressed: _busy ? null : () => _create(replace: true),
                      child: const Text('Make a new code'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The code itself, to write down, copy, or scan from the new phone.
class BackupCodeScreen extends StatelessWidget {
  const BackupCodeScreen({super.key, required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final sky = context.sky;
    final pretty = BackupCode.format(code);
    return Scaffold(
      appBar: AppBar(title: const Text('Your backup code')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Write it down or keep a screenshot somewhere safe, like a photo album or a '
              'notes app that is backed up. Anyone with this code can open your account.',
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: sky.muted),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              decoration: BoxDecoration(
                color: sky.surfaceHigh,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: sky.outline),
              ),
              child: SelectableText(
                // Two lines, like it is easiest to write down: 3 groups, then 2.
                '${pretty.substring(0, 14)}\n${pretty.substring(15)}',
                textAlign: TextAlign.center,
                style: text.titleLarge?.copyWith(
                  fontFamily: 'monospace',
                  letterSpacing: 1.5,
                  color: sky.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                child: QrImageView(data: BackupCode.qrData(code), size: 180, padding: EdgeInsets.zero),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'On the new phone: "Restore with a backup code", then scan this.',
              textAlign: TextAlign.center,
              style: text.bodySmall?.copyWith(color: sky.muted),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: pretty));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code copied')));
                }
              },
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Copy code'),
            ),
            const SizedBox(height: 10),
            FilledButton(onPressed: () => Navigator.pop(context), child: const Text('I saved it')),
          ],
        ),
      ),
    );
  }
}
