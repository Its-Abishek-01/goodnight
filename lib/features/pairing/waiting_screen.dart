import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../settings/delete_data.dart';
import 'pair.dart';

class WaitingScreen extends StatelessWidget {
  const WaitingScreen({super.key, required this.pair});

  final Pair pair;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Share this code with your partner'),
              const SizedBox(height: 16),
              SelectableText(
                pair.code,
                style: Theme.of(context)
                    .textTheme
                    .displayMedium
                    ?.copyWith(letterSpacing: 8),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () =>
                    Clipboard.setData(ClipboardData(text: pair.code)),
                icon: const Icon(Icons.copy),
                label: const Text('Copy'),
              ),
              const SizedBox(height: 32),
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('Waiting for your partner to join...'),
              const SizedBox(height: 32),
              TextButton(
                onPressed: () => confirmDeleteData(context, pair),
                child: const Text('Cancel and delete my data'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
