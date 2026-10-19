import 'package:flutter_test/flutter_test.dart';
import 'package:goodnight/features/alarm/wake_sound.dart';

void main() {
  test('a missing doc means I pick, soft chimes', () {
    final c = WakeSoundChoice.fromMap(null);
    expect(c.picker, SoundPicker.me);
    expect(c.sound, 'chimes');
    expect(c.hasVoice, isFalse);
  });

  test('only the owner sees the phone sound; the voice note shows once recorded', () {
    const c = WakeSoundChoice();
    expect(soundOptions(c, forOwner: true), contains(phoneSoundId));
    expect(soundOptions(c, forOwner: false), isNot(contains(phoneSoundId)));
    expect(soundOptions(c, forOwner: true), isNot(contains(voiceSoundId)));
  });

  test('who may pick follows the owner\'s choice', () {
    const mine = WakeSoundChoice();
    const theirs = WakeSoundChoice(picker: SoundPicker.partner);
    expect(canPickSound(mine, owner: 'a', viewer: 'a'), isTrue);
    expect(canPickSound(mine, owner: 'a', viewer: 'b'), isFalse);
    expect(canPickSound(theirs, owner: 'a', viewer: 'a'), isFalse);
    expect(canPickSound(theirs, owner: 'a', viewer: 'b'), isTrue);
  });

  test('the alarm falls back to chimes when a file is missing', () {
    expect(resolveAlarmAudio('music_box'), 'assets/sounds/music_box.ogg');
    expect(resolveAlarmAudio('classic'), 'assets/alarm.wav');
    expect(resolveAlarmAudio('phone'), WakeTone.chimes.asset);
    expect(resolveAlarmAudio('phone', phonePath: '/x/p'), '/x/p');
    expect(resolveAlarmAudio('voice', voicePath: '/x/v.m4a'), '/x/v.m4a');
    expect(resolveAlarmAudio('nonsense'), WakeTone.chimes.asset);
  });

  test('labels', () {
    expect(soundLabel('birds'), 'Morning birds');
    expect(soundLabel(voiceSoundId, partnerName: 'Alex'), "Alex's voice note 💌");
    expect(soundLabel(phoneSoundId, phoneTitle: 'Argon'), 'Argon (phone)');
  });
}
