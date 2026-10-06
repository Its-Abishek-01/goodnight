import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'alarm_scheduler.dart';

/// Shows the personal QR code used by the hardest alarm challenge. Print it
/// or save the image, then stick it somewhere you have to walk to.
class AlarmQrScreen extends StatefulWidget {
  const AlarmQrScreen({super.key});

  @override
  State<AlarmQrScreen> createState() => _AlarmQrScreenState();
}

class _AlarmQrScreenState extends State<AlarmQrScreen> {
  String? _payload;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await AlarmPrefs.qrSecret();
    final r = await AlarmPrefs.qrReady();
    if (!mounted) return;
    setState(() {
      _payload = p;
      _ready = r;
    });
  }

  Future<void> _toggle() async {
    await AlarmPrefs.setQrReady(!_ready);
    if (mounted) setState(() => _ready = !_ready);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Alarm QR code')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'After 3 snoozes the alarm will only stop when you scan this code. '
            'Print it and stick it in the bathroom (or anywhere away from your bed).',
          ),
          const SizedBox(height: 24),
          if (_payload != null)
            Center(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                child: QrImageView(data: _payload!, size: 240),
              ),
            ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _toggle,
            child: Text(_ready ? 'Turn off QR challenge' : "I've placed it - turn on"),
          ),
          const SizedBox(height: 8),
          Text(
            _ready ? 'QR challenge is on.' : 'Off: snooze 3+ uses a typing challenge instead.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
