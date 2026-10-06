import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase_providers.dart';
import 'pair_providers.dart';
import 'pair_repository.dart';

class PairingScreen extends ConsumerStatefulWidget {
  const PairingScreen({super.key});

  @override
  ConsumerState<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends ConsumerState<PairingScreen> {
  final _name = TextEditingController();
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _run(
    Future<void> Function(String uid, String name) action,
  ) async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter your name first.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final uid = await ref.read(uidProvider.future);
      await action(uid, name);
    } on PairException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Something went wrong. Check your connection.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(pairRepositoryProvider);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 32),
            Text('GoodNight 🌙',
                style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: 8),
            const Text(
              'A sleep pact for two. One of you creates a code, the other enters it.',
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Your name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy
                  ? null
                  : () => _run(
                        (uid, name) => repo.createPair(uid: uid, name: name),
                      ),
              child: const Text('Create a pair code'),
            ),
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 24),
            TextField(
              controller: _code,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: "Partner's code",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _busy
                  ? null
                  : () => _run(
                        (uid, name) => repo.joinPair(
                          uid: uid,
                          name: name,
                          rawCode: _code.text,
                        ),
                      ),
              child: const Text('Join with code'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (_busy)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: LinearProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}
