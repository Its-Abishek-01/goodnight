import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../core/theme.dart';
import '../../core/widgets/cute_loader.dart';
import '../pairing/pair.dart';
import '../profile/person_avatar.dart';
import '../profile/profile.dart';
import 'share.dart';
import 'share_providers.dart';

String _nameOf(WidgetRef ref, Pair pair, String uid) {
  final n = ref.watch(peopleProvider)[uid]?.name ?? pair.nameOf(uid);
  return n.isEmpty ? 'Your partner' : n;
}

/// "Watch together" on Tonight: share your screen, or ask to see theirs.
class WatchTogetherCard extends ConsumerWidget {
  const WatchTogetherCard({super.key, required this.pair, required this.uid});

  final Pair pair;
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partner = _nameOf(ref, pair, pair.partnerUid(uid) ?? '');
    final session = ref.watch(shareControllerProvider);
    final ctrl = ref.read(shareControllerProvider.notifier);
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.live_tv_rounded, color: context.sky.accent),
                const SizedBox(width: 8),
                Text('Watch together', style: text.titleSmall),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Show $partner your screen with its sound, or ask to see theirs. '
              'Talk while you watch and send reactions.',
              style: text.bodySmall,
            ),
            if (session.message != null) ...[
              const SizedBox(height: 6),
              Text(session.message!, style: text.bodySmall?.copyWith(color: context.sky.accent)),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: session.active ? null : ctrl.shareMyScreen,
                  icon: const Icon(Icons.screen_share_outlined),
                  label: const Text('Share my screen'),
                ),
                OutlinedButton.icon(
                  onPressed: session.active ? null : ctrl.askToSee,
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('Ask to see'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Full screen: your partner asks to see your screen, or offers theirs.
class SharePromptScreen extends ConsumerStatefulWidget {
  const SharePromptScreen({super.key, required this.share, required this.pair, required this.uid});

  final Share share;
  final Pair pair;
  final String uid;

  @override
  ConsumerState<SharePromptScreen> createState() => _SharePromptScreenState();
}

class _SharePromptScreenState extends ConsumerState<SharePromptScreen> {
  @override
  void initState() {
    super.initState();
    HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.share;
    final asked = s.sharer == widget.uid; // they want to see my screen
    final other = asked ? s.viewer : s.sharer;
    final name = _nameOf(ref, widget.pair, other);
    final ctrl = ref.read(shareControllerProvider.notifier);
    final inbox = ref.read(shareInboxProvider.notifier);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              const Spacer(),
              PersonAvatar(uid: other, size: 76),
              const SizedBox(height: 18),
              Text(
                asked ? '$name wants to see your screen' : '$name wants to share their screen 🍿',
                textAlign: TextAlign.center,
                style: text.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(
                asked
                    ? 'They will see everything on your screen and hear your phone\'s sound '
                          'until you stop. Netflix, Prime and Hotstar show black.'
                    : 'Watch along on your phone. Turn on your mic to talk, and send reactions.',
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(color: context.sky.muted),
              ),
              const Spacer(),
              SizedBox(
                height: 54,
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    inbox.dismiss();
                    asked ? ctrl.shareMyScreen(request: s) : ctrl.watch(s);
                  },
                  icon: Icon(asked ? Icons.screen_share_outlined : Icons.play_arrow_rounded),
                  label: Text(asked ? 'Share my screen' : 'Watch', style: const TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  inbox.dismiss();
                  ctrl.decline(s);
                },
                child: const Text('Not now'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown by the app gate while a session runs on this phone.
class ShareSessionScreen extends ConsumerWidget {
  const ShareSessionScreen({super.key, required this.pair});

  final Pair pair;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(shareControllerProvider);
    return session.role == ShareRole.viewer
        ? _WatchView(pair: pair, session: session)
        : _SharingView(pair: pair, session: session);
  }
}

class _SharingView extends ConsumerWidget {
  const _SharingView({required this.pair, required this.session});

  final Pair pair;
  final ShareSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = _nameOf(ref, pair, session.partnerUid);
    final ctrl = ref.read(shareControllerProvider.notifier);
    final text = Theme.of(context).textTheme;
    final title = switch (session.phase) {
      SharePhase.starting => 'Getting your screen ready…',
      SharePhase.waiting => 'Waiting for $name to join…',
      SharePhase.connecting => 'Connecting to $name…',
      _ => 'Sharing your screen with $name',
    };
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                children: [
                  const Spacer(),
                  if (session.phase == SharePhase.live)
                    PersonAvatar(uid: session.partnerUid, size: 76)
                  else
                    const CuteLoader(size: 96),
                  const SizedBox(height: 18),
                  Text(title, textAlign: TextAlign.center, style: text.headlineSmall),
                  const SizedBox(height: 8),
                  if (session.phase == SharePhase.live) _Elapsed(since: session.liveSince),
                  const SizedBox(height: 12),
                  Text(
                    session.phase == SharePhase.live
                        ? 'Go to any app or video now. $name sees your screen until you stop. '
                              '${session.sound ? 'Your phone\'s sound goes too.' : 'Sound can\'t be shared on this phone.'}'
                        : 'Once $name joins, open the app or video you want to show.',
                    textAlign: TextAlign.center,
                    style: text.bodyMedium?.copyWith(color: context.sky.muted),
                  ),
                  const Spacer(),
                  if (session.phase == SharePhase.live) ...[
                    _ReactionBar(onTap: ctrl.sendReaction),
                    const SizedBox(height: 16),
                  ],
                  _Controls(session: session, onMic: ctrl.toggleMic, onStop: ctrl.stop),
                ],
              ),
            ),
            const Positioned.fill(child: IgnorePointer(child: FloatingReactions())),
          ],
        ),
      ),
    );
  }
}

class _WatchView extends ConsumerStatefulWidget {
  const _WatchView({required this.pair, required this.session});

  final Pair pair;
  final ShareSession session;

  @override
  ConsumerState<_WatchView> createState() => _WatchViewState();
}

class _WatchViewState extends ConsumerState<_WatchView> {
  bool _controls = true;
  Timer? _hide;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _autoHide();
  }

  @override
  void dispose() {
    _hide?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _autoHide() {
    _hide?.cancel();
    _hide = Timer(const Duration(seconds: 5), () {
      if (mounted && widget.session.phase == SharePhase.live) setState(() => _controls = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final name = _nameOf(ref, widget.pair, session.partnerUid);
    final ctrl = ref.read(shareControllerProvider.notifier);
    final renderer = ctrl.renderer;
    final live = session.phase == SharePhase.live && renderer != null;
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() => _controls = !_controls);
          if (_controls) _autoHide();
        },
        child: Stack(
          children: [
            if (live)
              Positioned.fill(
                child: RTCVideoView(renderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain),
              )
            else
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CuteLoader(size: 96),
                    const SizedBox(height: 16),
                    Text(
                      session.phase == SharePhase.asking
                          ? 'Waiting for $name to share…'
                          : 'Connecting to $name…',
                      style: const TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: ctrl.stop,
                      child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                    ),
                  ],
                ),
              ),
            if (live && _controls) ...[
              Positioned(
                top: 0,
                left: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: _LivePill(name: name, since: session.liveSince),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ReactionBar(onTap: (e) {
                          ctrl.sendReaction(e);
                          _autoHide();
                        }),
                        const SizedBox(height: 12),
                        _Controls(session: session, onMic: ctrl.toggleMic, onStop: ctrl.stop, dark: true),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            const Positioned.fill(child: IgnorePointer(child: FloatingReactions())),
          ],
        ),
      ),
    );
  }
}

class _LivePill extends StatelessWidget {
  const _LivePill({required this.name, required this.since});

  final String name;
  final DateTime? since;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(color: Color(0xFFFF6B6B), shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text('$name\'s screen · ', style: const TextStyle(color: Colors.white, fontSize: 13)),
          _Elapsed(since: since, style: const TextStyle(color: Colors.white, fontSize: 13)),
        ],
      ),
    );
  }
}

/// A ticking "12:04" since the session went live.
class _Elapsed extends StatefulWidget {
  const _Elapsed({required this.since, this.style});

  final DateTime? since;
  final TextStyle? style;

  @override
  State<_Elapsed> createState() => _ElapsedState();
}

class _ElapsedState extends State<_Elapsed> {
  late final Timer _tick = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final since = widget.since;
    final d = since == null ? Duration.zero : DateTime.now().difference(since);
    return Text(elapsedLabel(d), style: widget.style ?? Theme.of(context).textTheme.titleMedium);
  }
}

class _ReactionBar extends StatelessWidget {
  const _ReactionBar({required this.onTap});

  final void Function(String emoji) onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final e in shareReactions)
            IconButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                onTap(e);
              },
              icon: Text(e, style: const TextStyle(fontSize: 24)),
            ),
        ],
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.session, required this.onMic, required this.onStop, this.dark = false});

  final ShareSession session;
  final VoidCallback onMic;
  final VoidCallback onStop;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final busy = session.phase != SharePhase.live;
    final bg = dark ? Colors.black.withValues(alpha: 0.5) : context.sky.surface;
    final fg = dark ? Colors.white : context.sky.text;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (!busy) ...[
          _RoundButton(
            icon: session.micOn ? Icons.mic : Icons.mic_off,
            label: session.micOn ? 'Mic on' : 'Mic off',
            background: session.micOn ? context.sky.accent : bg,
            foreground: session.micOn ? context.sky.onAccent : fg,
            onTap: onMic,
          ),
          const SizedBox(width: 28),
        ],
        _RoundButton(
          icon: Icons.close_rounded,
          label: session.role == ShareRole.sharer ? (busy ? 'Cancel' : 'Stop sharing') : 'Leave',
          background: const Color(0xFFE24B4A),
          foreground: Colors.white,
          labelColor: fg,
          onTap: onStop,
        ),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
    required this.onTap,
    this.labelColor,
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;
  final Color? labelColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: background,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(width: 60, height: 60, child: Icon(icon, color: foreground, size: 28)),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(fontSize: 12, color: labelColor ?? foreground)),
      ],
    );
  }
}

/// Reactions from either phone float up from the bottom right and fade.
class FloatingReactions extends ConsumerStatefulWidget {
  const FloatingReactions({super.key});

  @override
  ConsumerState<FloatingReactions> createState() => _FloatingReactionsState();
}

class _FloatingReactionsState extends ConsumerState<FloatingReactions> {
  final _live = <ShareReaction>[];
  final _rand = Random();
  final _drift = <int, double>{};

  @override
  Widget build(BuildContext context) {
    ref.listen(shareControllerProvider.select((s) => s.reaction), (_, r) {
      if (r == null || _live.any((x) => x.id == r.id)) return;
      setState(() {
        _live.add(r);
        _drift[r.id] = _rand.nextDouble();
      });
    });
    return LayoutBuilder(
      builder: (context, box) => Stack(
        children: [
          for (final r in _live)
            TweenAnimationBuilder<double>(
              key: ValueKey(r.id),
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 2600),
              curve: Curves.easeOut,
              onEnd: () => setState(() {
                _live.removeWhere((x) => x.id == r.id);
                _drift.remove(r.id);
              }),
              builder: (context, t, child) {
                final d = _drift[r.id] ?? 0.5;
                return Positioned(
                  right: 24 + d * 60 + sin(t * pi * 2 + d * 6) * 14,
                  bottom: 110 + t * box.maxHeight * 0.55,
                  child: Opacity(
                    opacity: (1 - t).clamp(0, 1),
                    child: Transform.scale(scale: 0.8 + t * 0.6, child: child),
                  ),
                );
              },
              child: Text(r.emoji, style: const TextStyle(fontSize: 40)),
            ),
        ],
      ),
    );
  }
}
