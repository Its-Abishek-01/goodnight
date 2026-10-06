import 'package:flutter_test/flutter_test.dart';
import 'package:goodnight/features/settings/features.dart';

void main() {
  test('missing personal choices mean everything is on', () {
    expect(PersonalFeatures.fromMap({}), PersonalFeatures.all);
    final f = PersonalFeatures.fromMap({'alarm': false});
    expect(f.alarm, isFalse);
    expect(f.nightMode, isTrue);
    expect(PersonalFeatures.fromMap(f.toMap()), f);
  });

  test('a couple without a shared doc has everything on', () {
    final s = SharedSettings.fromMap(null);
    expect(s.current, SharedFeatures.all);
    expect(s.proposal, isNull);
  });

  test('shared settings read the proposal and who made it', () {
    final s = SharedSettings.fromMap({
      'current': null,
      'proposal': {'streak': true, 'moments': false, 'by': 'a'},
    });
    expect(s.current, SharedFeatures.all);
    expect(s.proposal, const SharedFeatures(moments: false));
    expect(s.by, 'a');
  });

  test('describeChange names only what changes', () {
    const all = SharedFeatures.all;
    expect(describeChange(all, all.copyWith(moments: false)), 'turn off Moments');
    expect(
      describeChange(const SharedFeatures(streak: false, moments: false), all),
      'turn on Streak & coupons and turn on Moments',
    );
  });
}
