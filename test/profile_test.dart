import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:goodnight/core/widgets/cute_icons.dart';
import 'package:goodnight/features/pairing/pair.dart';
import 'package:goodnight/features/pairing/partner_color.dart';
import 'package:goodnight/features/profile/profile.dart';

void main() {
  const pair = Pair(
    id: 'p',
    code: '',
    members: ['me', 'them'],
    names: {'me': 'Sam', 'them': 'Alex'},
    status: PairStatus.active,
  );
  final mine = Uint8List.fromList([1]);
  final theirs = Uint8List.fromList([2]);
  final custom = Uint8List.fromList([3]);

  test('without a pet name or custom photo people show as themselves', () {
    final p = resolvePerson(pair: pair, viewer: 'me', uid: 'them', photos: {'them': theirs}, nickname: Nickname.none);
    expect(p.name, 'Alex');
    expect(p.photo, theirs);
    expect(p.color, PartnerColor.rose);
  });

  test('your pet name and photo replace your partner only, never you', () {
    final nick = Nickname(petName: 'Sunshine', photo: custom);
    final them = resolvePerson(pair: pair, viewer: 'me', uid: 'them', photos: {'them': theirs}, nickname: nick);
    expect(them.name, 'Sunshine');
    expect(them.photo, custom);
    final me = resolvePerson(pair: pair, viewer: 'me', uid: 'me', photos: {'me': mine}, nickname: nick);
    expect(me.name, 'Sam');
    expect(me.photo, mine);
  });

  test('a blank pet name is ignored', () {
    expect(Nickname.fromMap({'petName': '   '}).petName, isNull);
    expect(Nickname.fromMap(null).petName, isNull);
    expect(Nickname.fromMap({'petName': ' Jaan '}).petName, 'Jaan');
  });

  test('keyframes ease between points and hold at the ends', () {
    const track = [(0.0, 0.0), (0.5, 10.0), (1.0, 0.0)];
    expect(keyframe(0, track), 0);
    expect(keyframe(0.5, track), 10);
    expect(keyframe(0.25, track), closeTo(5, 0.01));
    expect(keyframe(1, track), 0);
    expect(keyframe(2, track), 0);
  });
}
