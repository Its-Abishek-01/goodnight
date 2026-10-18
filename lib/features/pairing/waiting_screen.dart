import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/theme.dart';
import '../../core/widgets/cute_loader.dart';
import '../settings/delete_data.dart';
import 'pair.dart';
import 'pair_repository.dart';

/// Shown to the person who created the pair until their partner joins, by
/// scanning the QR code or typing the code.
class WaitingScreen extends StatelessWidget {
  const WaitingScreen({super.key, required this.pair});

  final Pair pair;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final sky = context.sky;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Your partner scans this',
                  textAlign: TextAlign.center,
                  style: text.titleMedium,
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: QrImageView(
                    data: PairRepository.pairQrData(pair.code),
                    size: 200,
                    padding: EdgeInsets.zero,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.circle,
                      color: Color(0xFF1E1A45),
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.circle,
                      color: Color(0xFF1E1A45),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'or types the code',
                  textAlign: TextAlign.center,
                  style: text.bodyMedium?.copyWith(color: sky.muted),
                ),
                const SizedBox(height: 8),
                // The trailing letter spacing would push the code off-centre.
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: SelectableText(
                    pair.code,
                    textAlign: TextAlign.center,
                    style: text.displaySmall?.copyWith(
                      letterSpacing: 8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: pair.code));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Code copied')),
                      );
                    }
                  },
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Copy code'),
                ),
                const SizedBox(height: 28),
                const CuteLoader(size: 96),
                const SizedBox(height: 12),
                Text(
                  'Waiting for your partner to join…',
                  textAlign: TextAlign.center,
                  style: text.bodyMedium?.copyWith(color: sky.muted),
                ),
                const SizedBox(height: 28),
                TextButton(
                  onPressed: () => confirmDeleteData(context, pair),
                  style: TextButton.styleFrom(foregroundColor: sky.muted),
                  child: const Text('Cancel and delete my data'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
