import 'package:flutter_test/flutter_test.dart';
import 'package:goodnight/features/coupons/coupon.dart';

void main() {
  test('next milestone is the first tier above the streak', () {
    expect(nextMilestone(0), 7);
    expect(nextMilestone(6), 7);
    expect(nextMilestone(7), 14);
    expect(nextMilestone(29), 30);
    expect(nextMilestone(60), isNull);
  });

  test('coupon ideas are not empty', () {
    expect(couponIdeas, isNotEmpty);
  });
}
