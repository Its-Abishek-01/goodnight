import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../pairing/pair.dart';
import '../../core/widgets/cute_loader.dart';
import 'love_note.dart';
import 'love_note_providers.dart';
import 'love_note_repository.dart';

String _clock(BuildContext context, DateTime t) =>
    TimeOfDay.fromDateTime(t).format(context);

/// The entry point on Tonight: a button that opens the composer, with the read
/// receipt of the last note you sent underneath.
class LoveNoteButton extends ConsumerWidget {
  const LoveNoteButton({super.key, required this.pair, required this.uid});

  final Pair pair;
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partnerUid = pair.partnerUid(uid) ?? '';
    if (partnerUid.isEmpty) return const SizedBox.shrink();
    final last = ref.watch(lastSentNoteProvider);
    final partnerName = pair.nameOf(partnerUid);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 52,
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _openComposer(context, ref, pair, uid, partnerName),
            icon: const Icon(Icons.favorite_border),
            label: Text('Send $partnerName a love note', style: const TextStyle(fontSize: 15)),
          ),
        ),
        if (last != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 6),
            child: Text(
              last.seenAt != null
                  ? '✓✓ Seen at ${_clock(context, last.seenAt!)}'
                  : '✓ Sent at ${_clock(context, last.sentAt)} · "${last.text}"',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}

void _openComposer(
  BuildContext context,
  WidgetRef ref,
  Pair pair,
  String uid,
  String partnerName,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.sky.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _Composer(pair: pair, uid: uid, partnerName: partnerName),
  );
}

class _Composer extends ConsumerStatefulWidget {
  const _Composer({required this.pair, required this.uid, required this.partnerName});

  final Pair pair;
  final String uid;
  final String partnerName;

  @override
  ConsumerState<_Composer> createState() => _ComposerState();
}

class _ComposerState extends ConsumerState<_Composer> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      await ref.read(loveNoteRepositoryProvider).send(
            pairId: widget.pair.id,
            uid: widget.uid,
            text: text,
          );
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Sent to ${widget.partnerName} 💌')));
    } on LoveNoteException catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Could not send. Try again.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('A sudden love note', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'It fills ${widget.partnerName}\'s screen the moment it lands.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLength: loveNoteMaxLen,
            minLines: 1,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Say something sweet…',
              border: OutlineInputBorder(),
            ),
            onSubmitted: _send,
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final preset in loveNotePresets)
                ActionChip(
                  label: Text(preset),
                  onPressed: _sending ? null : () => _send(preset),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 50,
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _sending ? null : () => _send(_controller.text),
              icon: _sending
                  ? const CuteLoader(size: 30)
                  : const Icon(Icons.send),
              label: const Text('Send'),
            ),
          ),
        ],
      ),
    );
  }
}
