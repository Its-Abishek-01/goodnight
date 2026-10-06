import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/alarm/alarm_providers.dart';
import '../features/alarm/alarm_ring_screen.dart';
import '../features/pairing/home_screen.dart';
import '../features/pairing/pair.dart';
import '../features/pairing/pair_providers.dart';
import '../features/pairing/pairing_screen.dart';
import '../features/pairing/waiting_screen.dart';
import '../features/settings/delete_data.dart';
import 'firebase_providers.dart';

class GoodNightApp extends StatelessWidget {
  const GoodNightApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GoodNight',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF3F3D8F),
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const _Gate(),
    );
  }
}

/// Shown while a pair is being deleted. Either person can finish a deletion
/// that was interrupted.
class _Closing extends StatelessWidget {
  const _Closing({required this.pair});

  final Pair pair;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'This pact is being ended and its data deleted.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => confirmDeleteData(context, pair),
                child: const Text('Finish deleting'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Routes to pairing, the waiting screen, or home depending on pair state.
class _Gate extends ConsumerWidget {
  const _Gate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ringing = ref.watch(ringProvider);
    if (ringing != null) return AlarmRingScreen(alarmId: ringing);

    final uid = ref.watch(uidProvider);
    final pair = ref.watch(pairProvider);

    if (uid.hasError || pair.hasError) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Could not connect. Check your internet and Firebase setup.',
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    ref.invalidate(uidProvider);
                    ref.invalidate(pairProvider);
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (!uid.hasValue || !pair.hasValue) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final p = pair.value;
    if (p == null) return const PairingScreen();
    if (p.closing) return _Closing(pair: p);
    if (p.status == PairStatus.waiting) return WaitingScreen(pair: p);
    return HomeScreen(pair: p, uid: uid.value!);
  }
}
