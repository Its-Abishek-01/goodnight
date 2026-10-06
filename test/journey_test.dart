import 'package:flutter_test/flutter_test.dart';
import 'package:goodnight/features/checkin/moon_journey.dart';
import 'package:goodnight/features/checkin/night_log.dart';
import 'package:goodnight/features/pairing/pair.dart';
import 'package:goodnight/features/pairing/partner_color.dart';

void main() {
  final evening = DateTime(2026, 10, 6, 22, 40);
  final morning = DateTime(2026, 10, 7, 6, 50);

  test('stage follows check-in and wake-up', () {
    expect(stageOf(const PlayerNight()), JourneyStage.awake);
    expect(stageOf(PlayerNight(checkedInAt: evening)), JourneyStage.asleep);
    expect(stageOf(PlayerNight(checkedInAt: evening, wokeAt: morning)), JourneyStage.up);
  });

  test('you climb from the left, your partner from the right, toward the moon', () {
    final meAwake = journeyT(JourneyStage.awake, isMe: true);
    final meAsleep = journeyT(JourneyStage.asleep, isMe: true);
    final themAwake = journeyT(JourneyStage.awake, isMe: false);
    final themAsleep = journeyT(JourneyStage.asleep, isMe: false);
    expect(meAwake, lessThan(meAsleep));
    expect(themAwake, greaterThan(themAsleep));
    // Both stop short of the top so the avatars sit beside the moon.
    expect(meAsleep, lessThan(0.5));
    expect(themAsleep, greaterThan(0.5));
    expect(journeyT(JourneyStage.up, isMe: true), meAwake);
  });

  test('caption describes where the two of you are', () {
    const a = JourneyStage.awake, s = JourneyStage.asleep, u = JourneyStage.up;
    expect(journeyCaption(a, a, 'Alex'), 'Head for the moon together tonight.');
    expect(journeyCaption(a, s, 'Alex'), 'Alex is on the moon. Join them.');
    expect(journeyCaption(s, a, 'Alex'), "You're on the moon. Waiting for Alex.");
    expect(journeyCaption(s, s, 'Alex'), 'You both reached the moon. Sleep well.');
    expect(journeyCaption(u, u, 'Alex'), 'Good morning, you two.');
    expect(journeyCaption(a, a, ''), 'Head for the moon together tonight.');
    expect(journeyCaption(a, s, ''), 'Your partner is on the moon. Join them.');
  });

  test('colours default to sky for the creator and rose for the partner', () {
    const pair = Pair(
      id: 'p',
      code: '',
      members: ['a', 'b'],
      names: {'a': 'Sam', 'b': 'Alex'},
      status: PairStatus.active,
      colors: {'b': 'mint', 'a': 'not-a-colour'},
    );
    expect(pair.colorOf('a'), PartnerColor.sky);
    expect(pair.colorOf('b'), PartnerColor.mint);
    const fresh = Pair(id: 'p', code: '', members: ['a', 'b'], names: {}, status: PairStatus.active);
    expect(fresh.colorOf('b'), PartnerColor.rose);
    expect(PartnerColor.tryParse('peach'), PartnerColor.peach);
    expect(PartnerColor.tryParse(null), isNull);
  });
}
