import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/theme.dart';
import 'pair_repository.dart';

/// Scans the QR code on your partner's waiting screen (or, with [parse], any
/// other GoodNight code such as a backup). Pops with the code, or null.
class ScanCodeScreen extends StatefulWidget {
  const ScanCodeScreen({
    super.key,
    this.title = "Scan your partner's code",
    this.hint = 'Point the camera at the QR code on their screen.',
    this.wrong = "That isn't a GoodNight code. Scan the one on your partner's waiting screen.",
    this.parse = PairRepository.codeFromQr,
  });

  final String title;
  final String hint;
  final String wrong;
  final String? Function(String raw) parse;

  @override
  State<ScanCodeScreen> createState() => _ScanCodeScreenState();
}

class _ScanCodeScreenState extends State<ScanCodeScreen> {
  bool _done = false;
  bool _wrong = false;

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    for (final b in capture.barcodes) {
      final raw = b.rawValue;
      if (raw == null) continue;
      final code = widget.parse(raw);
      if (code != null) {
        _done = true;
        Navigator.pop(context, code);
        return;
      }
    }
    if (!_wrong) setState(() => _wrong = true);
  }

  @override
  Widget build(BuildContext context) {
    final sky = context.sky;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Text(
                widget.hint,
                textAlign: TextAlign.center,
                style: TextStyle(color: sky.muted),
              ),
              const SizedBox(height: 20),
              AspectRatio(
                aspectRatio: 1,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: sky.accent, width: 3),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: MobileScanner(
                    onDetect: _onDetect,
                    errorBuilder: (context, error) => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Camera unavailable. Allow camera access in Settings, or type the code instead.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              AnimatedOpacity(
                opacity: _wrong ? 1 : 0,
                duration: const Duration(milliseconds: 250),
                child: Text(
                  widget.wrong,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
