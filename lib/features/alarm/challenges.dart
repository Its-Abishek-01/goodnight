import 'dart:math';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

enum ChallengeKind { tap, math, type, qr }

/// Which challenge to show after [snoozes] snoozes. The QR scan needs a code
/// the user has printed, so it falls back to typing when none is set up.
ChallengeKind challengeFor(int snoozes, {required bool qrReady}) {
  if (snoozes <= 0) return ChallengeKind.tap;
  if (snoozes == 1) return ChallengeKind.math;
  if (snoozes == 2 || !qrReady) return ChallengeKind.type;
  return ChallengeKind.qr;
}

class Challenge extends StatelessWidget {
  const Challenge({
    super.key,
    required this.kind,
    required this.onSolved,
    this.qrPayload,
  });

  final ChallengeKind kind;
  final VoidCallback onSolved;
  final String? qrPayload;

  @override
  Widget build(BuildContext context) {
    switch (kind) {
      case ChallengeKind.tap:
        return FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(64)),
          onPressed: onSolved,
          icon: const Icon(Icons.alarm_off),
          label: const Text("I'm awake"),
        );
      case ChallengeKind.math:
        return _MathChallenge(onSolved: onSolved);
      case ChallengeKind.type:
        return _TypeChallenge(onSolved: onSolved);
      case ChallengeKind.qr:
        return _QrChallenge(payload: qrPayload ?? '', onSolved: onSolved);
    }
  }
}

class _MathChallenge extends StatefulWidget {
  const _MathChallenge({required this.onSolved});
  final VoidCallback onSolved;

  @override
  State<_MathChallenge> createState() => _MathChallengeState();
}

class _MathChallengeState extends State<_MathChallenge> {
  final _rand = Random();
  final _answer = TextEditingController();
  late int _a = 12 + _rand.nextInt(8);
  late int _b = 4 + _rand.nextInt(6);
  bool _wrong = false;

  @override
  void dispose() {
    _answer.dispose();
    super.dispose();
  }

  void _check() {
    if (int.tryParse(_answer.text.trim()) == _a * _b) {
      widget.onSolved();
    } else {
      setState(() {
        _wrong = true;
        _a = 12 + _rand.nextInt(8);
        _b = 4 + _rand.nextInt(6);
        _answer.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$_a × $_b = ?', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        TextField(
          controller: _answer,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          onSubmitted: (_) => _check(),
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            errorText: _wrong ? 'Wrong, here is a new one' : null,
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(onPressed: _check, child: const Text('Turn off')),
      ],
    );
  }
}

class _TypeChallenge extends StatefulWidget {
  const _TypeChallenge({required this.onSolved});
  final VoidCallback onSolved;

  @override
  State<_TypeChallenge> createState() => _TypeChallengeState();
}

class _TypeChallengeState extends State<_TypeChallenge> {
  static const _sentences = [
    'I am awake and getting out of bed',
    'Today I will be on time for school',
    'Good morning, I am standing up now',
  ];

  final _input = TextEditingController();
  late final String _target = _sentences[Random().nextInt(_sentences.length)];

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  bool get _ok =>
      _input.text.trim().toLowerCase() == _target.toLowerCase();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text('Type this sentence exactly:'),
        const SizedBox(height: 8),
        Text(_target, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        TextField(
          controller: _input,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        FilledButton(onPressed: _ok ? widget.onSolved : null, child: const Text('Turn off')),
      ],
    );
  }
}

class _QrChallenge extends StatefulWidget {
  const _QrChallenge({required this.payload, required this.onSolved});
  final String payload;
  final VoidCallback onSolved;

  @override
  State<_QrChallenge> createState() => _QrChallengeState();
}

class _QrChallengeState extends State<_QrChallenge> {
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text('Get up and scan your GoodNight QR code'),
        const SizedBox(height: 12),
        SizedBox(
          height: 260,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: MobileScanner(
              onDetect: (capture) {
                if (_done) return;
                for (final b in capture.barcodes) {
                  if (b.rawValue == widget.payload) {
                    _done = true;
                    widget.onSolved();
                    return;
                  }
                }
              },
              errorBuilder: (context, error) => const Center(
                child: Text('Camera unavailable. Allow camera access in Settings.'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
