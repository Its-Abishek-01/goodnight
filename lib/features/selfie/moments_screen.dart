import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../pairing/pair.dart';
import 'selfie.dart';
import 'selfie_providers.dart';
import 'selfie_repository.dart';

/// Send a quick selfie to your partner and see theirs. Opening a selfie sends
/// the read receipt.
class MomentsScreen extends ConsumerStatefulWidget {
  const MomentsScreen({super.key, required this.pair, required this.uid});

  final Pair pair;
  final String uid;

  @override
  ConsumerState<MomentsScreen> createState() => _MomentsScreenState();
}

class _MomentsScreenState extends ConsumerState<MomentsScreen> {
  final _marked = <String>{};
  bool _sending = false;

  Future<void> _send(List<Selfie> all) async {
    if (sentToday(all, widget.uid, DateTime.now()) >= selfieDailyLimit) {
      _toast('You have sent $selfieDailyLimit selfies today. Come back tomorrow.');
      return;
    }
    final picked = await ImagePicker().pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      maxWidth: 720,
      maxHeight: 720,
      imageQuality: 70,
    );
    if (picked == null) return;
    setState(() => _sending = true);
    try {
      await ref.read(selfieRepositoryProvider).send(
            pairId: widget.pair.id,
            uid: widget.uid,
            bytes: await picked.readAsBytes(),
          );
      _toast('Sent 📸');
    } on SelfieException catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast('Could not send. Check your connection.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  /// Opening this screen marks the partner's selfies as seen.
  void _markSeen(List<Selfie> all) {
    final repo = ref.read(selfieRepositoryProvider);
    for (final s in all) {
      if (s.from != widget.uid && s.seenAt == null && _marked.add(s.id)) {
        repo.markSeen(widget.pair.id, s.id).catchError((Object _) {
          _marked.remove(s.id);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(selfiesProvider).value ?? const <Selfie>[];
    WidgetsBinding.instance.addPostFrameCallback((_) => _markSeen(all));
    final left = selfieDailyLimit - sentToday(all, widget.uid, DateTime.now());

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Moments', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        const Text(
          'Send a random selfie. The latest one from your partner shows on your home-screen widget. Photos disappear after a week.',
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _sending ? null : () => _send(all),
          icon: const Icon(Icons.camera_front),
          label: Text(_sending ? 'Sending...' : 'Send a selfie ($left left today)'),
        ),
        const SizedBox(height: 16),
        if (all.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('No selfies yet. Send the first one 📸')),
          )
        else
          GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [for (final s in all) _tile(context, s)],
          ),
      ],
    );
  }

  Widget _tile(BuildContext context, Selfie s) {
    final mine = s.from == widget.uid;
    final label = mine
        ? (s.seenAt != null ? 'Seen ${clockLabel(s.seenAt!)}' : 'Delivered')
        : (s.seenAt == null ? 'New' : clockLabel(s.createdAt));
    return GestureDetector(
      onTap: () => showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.memory(s.bytes, gaplessPlayback: true),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(captionFor(
                  mine ? 'You' : widget.pair.nameOf(s.from),
                  s.createdAt,
                )),
              ),
            ],
          ),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.memory(s.bytes, fit: BoxFit.cover, gaplessPlayback: true),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                color: Colors.black54,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  '${mine ? 'You' : widget.pair.nameOf(s.from)} · $label',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
