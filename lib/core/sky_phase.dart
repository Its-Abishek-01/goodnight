import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme.dart';

/// The current time of day, checked every minute. [preview] pins a phase
/// so you can see the morning look at night (long-press the logo).
class SkyPhaseNotifier extends Notifier<SkyPhase> {
  SkyPhase? _preview;

  @override
  SkyPhase build() {
    final timer = Timer.periodic(const Duration(minutes: 1), (_) => _refresh());
    ref.onDispose(timer.cancel);
    return _preview ?? skyPhaseAt(DateTime.now());
  }

  void _refresh() => state = _preview ?? skyPhaseAt(DateTime.now());

  /// Cycles night → dawn → day → dusk → back to the real time.
  /// Returns the pinned phase, or null when back to automatic.
  SkyPhase? cyclePreview() {
    const order = [SkyPhase.night, SkyPhase.dawn, SkyPhase.day, SkyPhase.dusk];
    final i = _preview == null ? -1 : order.indexOf(_preview!);
    _preview = i + 1 < order.length ? order[i + 1] : null;
    _refresh();
    return _preview;
  }
}

final skyPhaseProvider = NotifierProvider<SkyPhaseNotifier, SkyPhase>(SkyPhaseNotifier.new);
