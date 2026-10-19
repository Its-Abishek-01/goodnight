import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

/// A wake-up tone that ships with the app (scripts/make-sounds.py), so both
/// phones have it and either of you can pick it.
enum WakeTone {
  chimes('chimes', 'Soft chimes', 'assets/sounds/chimes.ogg'),
  musicBox('music_box', 'Music box', 'assets/sounds/music_box.ogg'),
  birds('birds', 'Morning birds', 'assets/sounds/birds.ogg'),
  sunrisePiano('sunrise_piano', 'Sunrise piano', 'assets/sounds/sunrise_piano.ogg'),
  classic('classic', 'Classic beep', 'assets/alarm.wav');

  const WakeTone(this.id, this.label, this.asset);

  final String id;
  final String label;
  final String asset;

  static WakeTone? byId(String? id) {
    for (final t in values) {
      if (t.id == id) return t;
    }
    return null;
  }
}

/// One of the phone's own alarm sounds, copied into the app. Only the owner
/// can pick it: the partner's phone does not have it.
const phoneSoundId = 'phone';

/// The voice note the partner recorded.
const voiceSoundId = 'voice';

const defaultWakeSound = 'chimes';
const voiceNoteMaxBytes = 400000;

/// Who chooses a person's wake-up sound.
enum SoundPicker { me, partner }

/// `alarmSounds/{owner}`: what [owner]'s alarm plays. The owner decides who
/// picks ([picker]); the partner can always record a voice note for them.
class WakeSoundChoice {
  const WakeSoundChoice({
    this.picker = SoundPicker.me,
    this.sound = defaultWakeSound,
    this.pickedBy,
    this.voice,
    this.voiceAt,
    this.voiceBy,
    this.phoneTitle,
  });

  static const initial = WakeSoundChoice();

  final SoundPicker picker;
  final String sound;
  final String? pickedBy;
  final Uint8List? voice;
  final DateTime? voiceAt;
  final String? voiceBy;

  /// The name of the phone sound the owner picked (the file stays on their phone).
  final String? phoneTitle;

  bool get hasVoice => voice != null && voice!.isNotEmpty;

  factory WakeSoundChoice.fromMap(Map<String, dynamic>? m) {
    if (m == null) return initial;
    return WakeSoundChoice(
      picker: m['picker'] == 'partner' ? SoundPicker.partner : SoundPicker.me,
      sound: m['sound'] as String? ?? defaultWakeSound,
      pickedBy: m['pickedBy'] as String?,
      voice: (m['voice'] as Blob?)?.bytes,
      voiceAt: (m['voiceAt'] as Timestamp?)?.toDate(),
      voiceBy: m['voiceBy'] as String?,
      phoneTitle: m['phoneTitle'] as String?,
    );
  }
}

/// The sounds [viewer] may choose from for [owner]'s alarm.
List<String> soundOptions(WakeSoundChoice c, {required bool forOwner}) => [
      for (final t in WakeTone.values) t.id,
      if (forOwner) phoneSoundId,
      if (c.hasVoice) voiceSoundId,
    ];

/// Whether [viewer] can change the sound of [owner]'s alarm right now.
bool canPickSound(WakeSoundChoice c, {required String owner, required String viewer}) =>
    owner == viewer ? c.picker == SoundPicker.me : c.picker == SoundPicker.partner;

String soundLabel(String id, {String? partnerName, String? phoneTitle}) => switch (id) {
      phoneSoundId => phoneTitle == null ? "Phone's alarm sound" : '$phoneTitle (phone)',
      voiceSoundId => "${partnerName ?? 'Partner'}'s voice note 💌",
      _ => WakeTone.byId(id)?.label ?? WakeTone.chimes.label,
    };

/// What the alarm should play: a bundled asset path or a file on this phone.
/// Falls back to the default tone when a phone sound or voice note is chosen
/// but its file is not here (yet).
String resolveAlarmAudio(String sound, {String? phonePath, String? voicePath}) {
  if (sound == phoneSoundId && phonePath != null) return phonePath;
  if (sound == voiceSoundId && voicePath != null) return voicePath;
  return (WakeTone.byId(sound) ?? WakeTone.chimes).asset;
}

class WakeSoundRepository {
  WakeSoundRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _ref(String pairId, String owner) =>
      _db.doc('pairs/$pairId/alarmSounds/$owner');

  Stream<WakeSoundChoice> watch(String pairId, String owner) =>
      _ref(pairId, owner).snapshots().map((s) => WakeSoundChoice.fromMap(s.data()));

  /// Owner only: who picks.
  Future<void> setPicker(String pairId, String owner, SoundPicker picker) =>
      _ref(pairId, owner).set({'picker': picker.name}, SetOptions(merge: true));

  /// Owner, or the partner when the owner let them pick.
  Future<void> setSound(String pairId, String owner, String sound, {required String by, String? phoneTitle}) =>
      _ref(pairId, owner).set({
        'sound': sound,
        'pickedBy': by,
        'phoneTitle': ?phoneTitle,
      }, SetOptions(merge: true));

  /// The partner's recorded wake-up message for [owner].
  Future<void> saveVoice(String pairId, String owner, Uint8List bytes, {required String by}) =>
      _ref(pairId, owner).set({
        'voice': Blob(bytes),
        'voiceAt': FieldValue.serverTimestamp(),
        'voiceBy': by,
      }, SetOptions(merge: true));
}
