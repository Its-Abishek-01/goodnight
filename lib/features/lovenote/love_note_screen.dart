import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../pairing/pair.dart';
import '../profile/person_avatar.dart';
import '../profile/profile.dart';
import 'love_note.dart';
import 'love_note_providers.dart';

String _clock(BuildContext context, DateTime t) =>
    TimeOfDay.fromDateTime(t).format(context);

/// A sudden love note, filling the screen. Shown by the app gate whenever an
/// unseen note from your partner is waiting. Seeing it is the read receipt.
class LoveNoteScreen extends ConsumerStatefulWidget {
  const LoveNoteScreen({super.key, required this.note, required this.pair});

  final LoveNote note;
  final Pair pair;

  @override
  ConsumerState<LoveNoteScreen> createState() => _LoveNoteScreenState();
}

class _LoveNoteScreenState extends ConsumerState<LoveNoteScreen> {
  @override
  void initState() {
    super.initState();
    HapticFeedback.mediumImpact();
    // Full-screen means they have seen it: send the read receipt.
    final pair = widget.pair;
    ref.read(loveNoteRepositoryProvider).markSeen(pair.id, widget.note.id).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final note = widget.note;
    final name = ref.watch(peopleProvider)[note.from]?.name ?? widget.pair.nameOf(note.from);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              PersonAvatar(uid: note.from, size: 72),
              const SizedBox(height: 16),
              Text('$name sent you', style: text.titleMedium),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                decoration: BoxDecoration(
                  color: context.sky.surface.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: context.sky.outline),
                ),
                child: Column(
                  children: [
                    Icon(Icons.favorite, color: context.sky.accent, size: 30),
                    const SizedBox(height: 16),
                    Text(
                      note.text,
                      textAlign: TextAlign.center,
                      style: text.headlineSmall?.copyWith(height: 1.3),
                    ),
                    const SizedBox(height: 16),
                    Text(_clock(context, note.sentAt), style: text.bodySmall),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                height: 54,
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => ref.read(loveNoteInboxProvider.notifier).dismiss(),
                  icon: const Icon(Icons.favorite),
                  label: const Text('Close', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
