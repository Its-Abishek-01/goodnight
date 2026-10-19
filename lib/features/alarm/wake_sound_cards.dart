import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/theme.dart';
import '../pairing/pair.dart';
import '../profile/profile.dart';
import 'alarm_scheduler.dart';
import 'wake_sound.dart';
import 'wake_sound_providers.dart';

/// One sound in a list: a play button, its name, and a tick when chosen.
class _SoundRow extends StatelessWidget {
  const _SoundRow({required this.label, required this.selected, required this.onPlay, this.onPick});

  final String label;
  final bool selected;
  final VoidCallback onPlay;
  final VoidCallback? onPick;

  @override
  Widget build(BuildContext context) {
    final sky = context.sky;
    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            IconButton.filledTonal(
              onPressed: onPlay,
              icon: const Icon(Icons.play_arrow_rounded),
              tooltip: 'Play',
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(label)),
            if (selected) Icon(Icons.check_circle_rounded, color: sky.accent),
          ],
        ),
      ),
    );
  }
}

/// Your own wake-up sound: who picks it, and the list when it is you.
class WakeSoundCard extends ConsumerWidget {
  const WakeSoundCard({super.key, required this.pair, required this.uid});

  final Pair pair;
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(wakeSoundProvider(uid)).value ?? WakeSoundChoice.initial;
    final partnerUid = pair.partnerUid(uid) ?? '';
    final partner = ref.watch(peopleProvider)[partnerUid]?.name ?? pair.nameOf(partnerUid);
    final repo = ref.read(wakeSoundRepositoryProvider);
    final text = Theme.of(context).textTheme;
    final muted = text.bodySmall?.copyWith(color: context.sky.muted);
    final mine = canPickSound(c, owner: uid, viewer: uid);

    Future<void> pick(String id) async {
      if (id == phoneSoundId) {
        final picked = await Sounds.pickPhoneSound();
        if (picked == null) return;
        await AlarmPrefs.setPhoneSoundPath(picked.path);
        await repo.setSound(pair.id, uid, id, by: uid, phoneTitle: picked.title);
      } else {
        await repo.setSound(pair.id, uid, id, by: uid);
      }
    }

    Future<void> play(String id) async => Sounds.previewSound(
          id,
          phonePath: await AlarmPrefs.phoneSoundPath(),
          voicePath: (await voiceNoteFile()).path,
        );

    return SizedBox(
      width: double.infinity,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Wake-up sound', style: text.titleSmall),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<SoundPicker>(
                  segments: [
                    const ButtonSegment(value: SoundPicker.me, label: Text('I pick')),
                    ButtonSegment(value: SoundPicker.partner, label: Text('$partner picks')),
                  ],
                  selected: {c.picker},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => repo.setPicker(pair.id, uid, s.first),
                ),
              ),
              const SizedBox(height: 8),
              if (!mine)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '$partner chooses what wakes you up. You can still listen to each sound.',
                    style: muted,
                  ),
                ),
              for (final id in soundOptions(c, forOwner: true))
                if (mine || id != phoneSoundId)
                  _SoundRow(
                    label: soundLabel(id, partnerName: partner, phoneTitle: c.phoneTitle),
                    selected: c.sound == id,
                    onPlay: () => play(id),
                    onPick: mine ? () => pick(id) : null,
                  ),
              if (!c.hasVoice)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('$partner can record a wake-up message for you on their Us tab.', style: muted),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Your partner's wake-up sound: pick it when they asked you to, and record
/// a wake-up message for them.
class PartnerWakeSoundCard extends ConsumerStatefulWidget {
  const PartnerWakeSoundCard({super.key, required this.pair, required this.uid});

  final Pair pair;
  final String uid;

  @override
  ConsumerState<PartnerWakeSoundCard> createState() => _PartnerWakeSoundCardState();
}

class _PartnerWakeSoundCardState extends ConsumerState<PartnerWakeSoundCard> {
  bool _recording = false;
  bool _sending = false;
  String? _recorded;
  int _seconds = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    if (_recording) Sounds.stopRecording();
    super.dispose();
  }

  Future<void> _start() async {
    if (!await Permission.microphone.request().isGranted) {
      _say('GoodNight needs the microphone to record your message.');
      return;
    }
    final path = '${(await getTemporaryDirectory()).path}/voice_note.m4a';
    try {
      await Sounds.startRecording(path);
    } catch (_) {
      _say("Couldn't start recording.");
      return;
    }
    setState(() {
      _recording = true;
      _recorded = null;
      _seconds = 0;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() => _seconds++);
      if (_seconds >= Sounds.maxRecording.inSeconds) _stop();
    });
  }

  Future<void> _stop() async {
    _timer?.cancel();
    final path = await Sounds.stopRecording();
    if (!mounted) return;
    setState(() {
      _recording = false;
      _recorded = path;
    });
  }

  Future<void> _send(String partnerUid) async {
    final path = _recorded;
    if (path == null) return;
    setState(() => _sending = true);
    try {
      final bytes = await File(path).readAsBytes();
      if (bytes.length >= voiceNoteMaxBytes) {
        _say('That message is too long. Keep it under 15 seconds.');
        return;
      }
      await ref.read(wakeSoundRepositoryProvider).saveVoice(widget.pair.id, partnerUid, bytes, by: widget.uid);
      setState(() => _recorded = null);
      _say('Sent 💌');
    } catch (_) {
      _say("Couldn't send it. Check your connection.");
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final partnerUid = widget.pair.partnerUid(widget.uid) ?? '';
    final c = ref.watch(wakeSoundProvider(partnerUid)).value ?? WakeSoundChoice.initial;
    final partner = ref.watch(peopleProvider)[partnerUid]?.name ?? widget.pair.nameOf(partnerUid);
    final repo = ref.read(wakeSoundRepositoryProvider);
    final text = Theme.of(context).textTheme;
    final sky = context.sky;
    final muted = text.bodySmall?.copyWith(color: sky.muted);
    final mine = canPickSound(c, owner: partnerUid, viewer: widget.uid);

    return SizedBox(
      width: double.infinity,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("$partner's wake-up sound", style: text.titleSmall),
              const SizedBox(height: 2),
              Text(
                mine
                    ? '$partner asked you to pick it.'
                    : '$partner picks it. Now: '
                        '${c.sound == voiceSoundId ? 'your voice note 💌' : soundLabel(c.sound, phoneTitle: c.phoneTitle)}.',
                style: muted,
              ),
              if (mine) ...[
                const SizedBox(height: 4),
                for (final id in soundOptions(c, forOwner: false))
                  _SoundRow(
                    label: id == voiceSoundId ? 'Your voice note 💌' : soundLabel(id),
                    selected: c.sound == id,
                    onPlay: () => id == voiceSoundId
                        ? _playVoice(c)
                        : Sounds.previewSound(id),
                    onPick: () => repo.setSound(widget.pair.id, partnerUid, id, by: widget.uid),
                  ),
              ],
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: sky.surfaceHigh.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: sky.outline),
                ),
                child: Column(
                  children: [
                    Text('Record a wake-up message', style: text.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      mine
                          ? 'Up to 15 seconds. Pick it above to make it their alarm.'
                          : 'Up to 15 seconds. $partner can pick it as their alarm.',
                      textAlign: TextAlign.center,
                      style: muted,
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: _sending ? null : (_recording ? _stop : _start),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: _recording ? 72 : 60,
                        height: _recording ? 72 : 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(context).colorScheme.tertiary,
                        ),
                        child: Icon(
                          _recording ? Icons.stop_rounded : Icons.mic_rounded,
                          size: 30,
                          color: Theme.of(context).colorScheme.onTertiary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _recording
                          ? 'Recording… ${_seconds}s / ${Sounds.maxRecording.inSeconds}s'
                          : _recorded != null
                              ? 'Ready to send'
                              : c.hasVoice && c.voiceBy == widget.uid
                                  ? 'You already sent one. Recording again replaces it.'
                                  : 'Tap to record',
                      style: muted,
                    ),
                    if (_recorded != null) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => Sounds.preview(path: _recorded),
                              icon: const Icon(Icons.play_arrow_rounded),
                              label: const Text('Listen'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              onPressed: _sending ? null : () => _send(partnerUid),
                              child: Text('Send to $partner'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Plays the voice note you sent, from the copy in the doc.
  Future<void> _playVoice(WakeSoundChoice c) async {
    if (!c.hasVoice) return;
    final file = File('${(await getTemporaryDirectory()).path}/sent_voice_note.m4a');
    await file.writeAsBytes(c.voice!, flush: true);
    await Sounds.preview(path: file.path);
  }
}
