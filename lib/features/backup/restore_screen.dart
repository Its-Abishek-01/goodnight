import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase_providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/cute_loader.dart';
import '../pairing/scan_code_screen.dart';
import 'backup_code.dart';
import 'backup_service.dart';

/// "Welcome back": signs this phone into the account a backup code belongs
/// to. The app gate then shows that account's pair as usual.
class RestoreScreen extends ConsumerStatefulWidget {
  const RestoreScreen({super.key});

  @override
  ConsumerState<RestoreScreen> createState() => _RestoreScreenState();
}

class _RestoreScreenState extends ConsumerState<RestoreScreen> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(backupServiceProvider).restore(_code.text);
      // Everything keyed by the user (the pair, the nights...) reloads.
      ref.invalidate(uidProvider);
      if (mounted) Navigator.pop(context);
    } on BackupException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _scan() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => const ScanCodeScreen(
          title: 'Scan your backup code',
          hint: 'On your old phone, open Us > Account backup > Show my code.',
          wrong: "That isn't a backup code. Scan the one under Account backup on your old phone.",
          parse: BackupCode.normalize,
        ),
      ),
    );
    if (code == null || !mounted) return;
    _code.text = BackupCode.format(code);
    await _restore();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final sky = context.sky;
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          children: [
            Icon(Icons.nightlight_round, size: 56, color: sky.accent),
            const SizedBox(height: 12),
            Text('Welcome back', textAlign: TextAlign.center, style: text.headlineSmall),
            const SizedBox(height: 6),
            Text(
              'Enter the backup code from your old phone to get your pair, streak and history back.',
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: sky.muted),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _code,
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              enableSuggestions: false,
              style: const TextStyle(fontFamily: 'monospace', letterSpacing: 1.2),
              decoration: const InputDecoration(
                labelText: 'Backup code',
                hintText: 'XXXX-XXXX-XXXX-XXXX-XXXX',
                prefixIcon: Icon(Icons.key_rounded),
              ),
              onSubmitted: (_) => _busy ? null : _restore(),
            ),
            const SizedBox(height: 16),
            if (_busy)
              const Center(child: CuteLoader(size: 72))
            else ...[
              FilledButton(onPressed: _restore, child: const Text('Restore my account')),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _scan,
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: const Text('Scan it from my old phone'),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 24),
            Text(
              "Lost the code? Your partner keeps their side; create a new pair and they can join again. "
              'The old streak stays with the old account.',
              textAlign: TextAlign.center,
              style: text.bodySmall?.copyWith(color: sky.muted),
            ),
          ],
        ),
      ),
    );
  }
}
