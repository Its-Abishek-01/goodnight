import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/firebase_providers.dart';
import '../pairing/pair_providers.dart';
import 'alarm_scheduler.dart';
import 'wake_sound.dart';

final wakeSoundRepositoryProvider =
    Provider((ref) => WakeSoundRepository(ref.watch(firestoreProvider)));

/// What [owner]'s alarm plays (either of you).
final wakeSoundProvider = StreamProvider.family<WakeSoundChoice, String>((ref, owner) async* {
  final pair = await ref.watch(pairProvider.future);
  if (pair == null) {
    yield WakeSoundChoice.initial;
    return;
  }
  yield* ref.watch(wakeSoundRepositoryProvider).watch(pair.id, owner);
});

/// Native helpers (SoundChannel.kt): previews, recording, phone sounds.
class Sounds {
  static const _channel = MethodChannel('com.wiozen.goodnight/sound');

  static const maxRecording = Duration(seconds: 15);

  /// Plays a bundled tone ([asset]) or a file ([path]) once.
  static Future<void> preview({String? asset, String? path}) async {
    try {
      await _channel.invokeMethod<bool>('preview', {'asset': asset, 'path': path});
    } catch (_) {}
  }

  static Future<void> previewSound(String id, {String? phonePath, String? voicePath}) =>
      switch (id) {
        phoneSoundId => preview(path: phonePath),
        voiceSoundId => preview(path: voicePath),
        _ => preview(asset: (WakeTone.byId(id) ?? WakeTone.chimes).asset),
      };

  static Future<void> stop() async {
    try {
      await _channel.invokeMethod<void>('stopPreview');
    } catch (_) {}
  }

  static Future<bool> startRecording(String path) async =>
      await _channel.invokeMethod<bool>('startRecording', {'path': path}) ?? false;

  /// The recording's path, or null when nothing was captured.
  static Future<String?> stopRecording() => _channel.invokeMethod<String>('stopRecording');

  /// Opens Android's alarm sound list. Returns the copied file and its name.
  static Future<({String path, String title})?> pickPhoneSound() async {
    final m = await _channel.invokeMethod<Map<Object?, Object?>>('pickPhoneSound');
    if (m == null) return null;
    return (path: m['path'] as String, title: m['title'] as String? ?? 'Phone sound');
  }
}

/// The voice note for this phone's alarm, as a file the alarm can play.
Future<File> voiceNoteFile() async =>
    File('${(await getApplicationSupportDirectory()).path}/wake_voice.m4a');

/// Keeps the alarm's sound in step with your choice: writes your partner's
/// voice note to a file when it is new, then re-sets pending alarms.
final wakeSoundSyncProvider = Provider<void>((ref) {
  final uid = ref.watch(uidProvider).value;
  if (uid == null) return;
  ref.listen(wakeSoundProvider(uid), (_, next) async {
    final c = next.value;
    if (c == null) return;
    try {
      String? voicePath;
      if (c.hasVoice) {
        final file = await voiceNoteFile();
        final at = c.voiceAt?.millisecondsSinceEpoch ?? 0;
        if (await AlarmPrefs.voiceAt() != at || !await file.exists()) {
          await file.writeAsBytes(c.voice!, flush: true);
          await AlarmPrefs.setVoiceAt(at);
        }
        voicePath = file.path;
      }
      final audio = resolveAlarmAudio(
        c.sound,
        phonePath: await AlarmPrefs.phoneSoundPath(),
        voicePath: voicePath,
      );
      if (audio != await AlarmPrefs.audioPath()) {
        await AlarmPrefs.setAudioPath(audio);
        await AlarmScheduler.refreshAudio();
      }
    } catch (_) {
      // Not on a phone (tests), or the alarm plugin is unavailable.
    }
  }, fireImmediately: true);
});
