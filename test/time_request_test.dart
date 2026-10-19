import 'package:flutter_test/flutter_test.dart';
import 'package:goodnight/features/blocking/time_request.dart';

TimeRequest _r(String id, String from, {String status = 'pending', DateTime? at}) => TimeRequest(
      id: id,
      from: from,
      minutes: 10,
      status: status,
      createdAt: at ?? DateTime(2026, 10, 19, 23, 50),
    );

void main() {
  final now = DateTime(2026, 10, 19, 23, 55);

  test("shows the partner's newest pending request", () {
    final all = [_r('a', 'me'), _r('b', 'partner'), _r('c', 'partner', at: DateTime(2026, 10, 19, 23, 40))];
    expect(incomingTimeRequest(all, 'me', now)?.id, 'b');
  });

  test('ignores answered, own and expired requests', () {
    expect(incomingTimeRequest([_r('a', 'partner', status: 'approved')], 'me', now), isNull);
    expect(incomingTimeRequest([_r('a', 'me')], 'me', now), isNull);
    expect(
      incomingTimeRequest([_r('a', 'partner', at: now.subtract(const Duration(minutes: 21)))], 'me', now),
      isNull,
    );
  });

  test('own requests older than two days are tidied away', () {
    final old = _r('a', 'me', at: now.subtract(const Duration(days: 3)));
    final fresh = _r('b', 'me');
    final theirs = _r('c', 'partner', at: now.subtract(const Duration(days: 3)));
    expect(expiredOwnRequests([old, fresh, theirs], 'me', now).map((r) => r.id), ['a']);
  });
}
