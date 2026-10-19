import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/features_providers.dart';
import 'blocker_channel.dart';

/// Shown on Tonight when night mode is on in the app but its Accessibility
/// service is off. Some phones (vivo's power manager) force-stop GoodNight in
/// the background, and Android then switches the service off by itself.
class NightModeOffCard extends ConsumerStatefulWidget {
  const NightModeOffCard({super.key});

  @override
  ConsumerState<NightModeOffCard> createState() => _NightModeOffCardState();
}

class _NightModeOffCardState extends ConsumerState<NightModeOffCard> with WidgetsBindingObserver {
  bool? _serviceOn;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    bool on;
    try {
      on = await Blocker.isServiceEnabled();
    } catch (_) {
      // Not on Android (tests): nothing to warn about.
      on = true;
    }
    if (mounted) setState(() => _serviceOn = on);
  }

  @override
  Widget build(BuildContext context) {
    final nightMode = ref.watch(myFeaturesProvider)?.nightMode ?? false;
    if (!nightMode || _serviceOn != false) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Night mode got switched off', style: text.titleSmall),
              const SizedBox(height: 4),
              Text(
                'Your phone stopped GoodNight in the background, and that turns its '
                'Accessibility service off. Turn it back on, then let GoodNight use '
                'power in the background so it stays on.',
                style: text.bodySmall,
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                children: [
                  FilledButton(
                    onPressed: Blocker.openAccessibilitySettings,
                    child: const Text('Turn on'),
                  ),
                  TextButton(
                    onPressed: Blocker.openBackgroundPower,
                    child: const Text('Keep it running'),
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
