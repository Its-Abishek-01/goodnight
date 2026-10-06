import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase_providers.dart';
import '../../core/theme.dart';
import 'pair_providers.dart';
import 'pair_repository.dart';
import 'partner_color.dart';

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
  PartnerColor _color = PartnerColor.sky;

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
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          children: [
            const SizedBox(height: 12),
            const Center(child: _FloatingLogo()),
            const SizedBox(height: 20),
            Text(
              'GoodNight',
              textAlign: TextAlign.center,
              style: text.displaySmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'A sleep pact for two',
              textAlign: TextAlign.center,
              style: text.titleMedium?.copyWith(color: context.sky.accent),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Your name',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 20),
            Text('Your colour', style: text.titleSmall),
            const SizedBox(height: 10),
            PartnerColorPicker(
              selected: _color,
              onChanged: (c) => setState(() => _color = c),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: _busy
                  ? null
                  : () => _run(
                        (uid, name) => repo.createPair(uid: uid, name: name, color: _color),
                      ),
              icon: const Icon(Icons.favorite),
              label: const Text('Create a pair code'),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('or join your partner', style: TextStyle(color: context.sky.muted)),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _code,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: "Partner's code",
                prefixIcon: Icon(Icons.vpn_key_outlined),
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
                          color: _color,
                        ),
                      ),
              child: const Text('Join with code'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
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

/// The logo bobbing gently, like the moon in the night sky.
class _FloatingLogo extends StatefulWidget {
  const _FloatingLogo();

  @override
  State<_FloatingLogo> createState() => _FloatingLogoState();
}

class _FloatingLogoState extends State<_FloatingLogo> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, -6 * Curves.easeInOut.transform(_c.value)),
        child: child,
      ),
      child: Image.asset('assets/logo.png', width: 132, height: 132),
    );
  }
}
