import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import 'app_update.dart';
import 'update_providers.dart';

/// The update button, progress bar or hint, by how far the update has got.
/// "Not tonight" sits under the button when [onLater] is given.
class UpdateActions extends ConsumerWidget {
  const UpdateActions({super.key, this.onLater});

  final VoidCallback? onLater;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(updateProvider);
    final n = ref.read(updateProvider.notifier);
    final sky = context.sky;
    final small = Theme.of(context).textTheme.bodySmall?.copyWith(color: sky.muted);

    Widget hint(String text) => Text(text, textAlign: TextAlign.center, style: small);

    final Widget body = switch (s.phase) {
      UpdatePhase.downloading => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: s.progress > 0 ? s.progress : null,
                minHeight: 8,
                color: sky.accent,
                backgroundColor: sky.outline,
              ),
            ),
            const SizedBox(height: 10),
            hint('Downloading ${(s.progress * 100).round()}%'),
          ],
        ),
      UpdatePhase.installing => Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: hint('Opening the installer…'),
        ),
      UpdatePhase.needsPermission => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            hint('Android needs your OK once: turn on "Allow from this source" '
                'for GoodNight, then come back here.'),
            const SizedBox(height: 12),
            FilledButton(onPressed: n.allowInstalls, child: const Text('Allow installs')),
          ],
        ),
      UpdatePhase.ready || UpdatePhase.failed => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (s.phase == UpdatePhase.failed) ...[
              hint("Couldn't download the update. Check your internet and try again."),
              const SizedBox(height: 12),
            ],
            FilledButton(
              onPressed: n.start,
              child: Text(s.phase == UpdatePhase.failed ? 'Try again' : 'Update now'),
            ),
            if (onLater != null)
              TextButton(
                onPressed: onLater,
                style: TextButton.styleFrom(foregroundColor: sky.muted),
                child: const Text('Not tonight'),
              ),
          ],
        ),
    };
    return AnimatedSize(duration: const Duration(milliseconds: 200), child: body);
  }
}

/// The release's highlights as little chips.
class UpdateHighlights extends StatelessWidget {
  const UpdateHighlights({super.key, required this.release});

  final AppRelease release;

  @override
  Widget build(BuildContext context) {
    final lines = releaseHighlights(release.notes, maxLen: 30);
    if (lines.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final l in lines)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: scheme.secondaryContainer,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              l,
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: scheme.onSecondaryContainer),
            ),
          ),
      ],
    );
  }
}

/// "0.2.1 → 0.2.2 · 14 MB".
String updateSubtitle(UpdateState s) {
  final r = s.release!;
  final from = s.installed.isEmpty ? 'Version ${r.version}' : '${s.installed} → ${r.version}';
  final size = formatSize(r.apkSize);
  return size.isEmpty ? from : '$from · $size';
}

/// Slides the update offer up from the bottom. Swiping it away counts as
/// "Not tonight"; a download already running carries on.
Future<void> showUpdateSheet(BuildContext context, WidgetRef ref) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: context.sky.surface,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => const _UpdateSheet(),
  );
  final s = ref.read(updateProvider);
  if (s.release != null && s.phase == UpdatePhase.ready) {
    await ref.read(updateProvider.notifier).later();
  }
}

class _UpdateSheet extends ConsumerWidget {
  const _UpdateSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(updateProvider, (_, next) {
      if (next.release == null && Navigator.canPop(context)) Navigator.pop(context);
    });
    final s = ref.watch(updateProvider);
    final release = s.release;
    if (release == null) return const SizedBox.shrink();
    final sky = context.sky;
    final text = Theme.of(context).textTheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.card_giftcard_rounded, size: 32, color: sky.accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Update ready', style: text.titleMedium),
                      Text(updateSubtitle(s), style: text.bodySmall?.copyWith(color: sky.muted)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            UpdateHighlights(release: release),
            const SizedBox(height: 20),
            UpdateActions(
              onLater: () {
                ref.read(updateProvider.notifier).later();
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown by the app gate when the installed version is too old to use: the
/// release notes carry [requiredMarker].
class UpdateRequiredScreen extends ConsumerWidget {
  const UpdateRequiredScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(updateProvider);
    final release = s.release;
    if (release == null) return const SizedBox.shrink();
    final sky = context.sky;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              const Spacer(),
              Icon(Icons.nightlight_round, size: 64, color: sky.accent),
              const SizedBox(height: 16),
              Text('Time for a new moon', style: text.headlineSmall, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                'This version of GoodNight is too old to keep working. '
                'Update to carry on with your pact.',
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(color: sky.muted),
              ),
              const SizedBox(height: 4),
              Text(updateSubtitle(s), style: text.bodySmall?.copyWith(color: sky.muted)),
              const SizedBox(height: 20),
              UpdateHighlights(release: release),
              const Spacer(),
              const UpdateActions(),
            ],
          ),
        ),
      ),
    );
  }
}
