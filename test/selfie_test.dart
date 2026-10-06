import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:goodnight/features/selfie/selfie.dart';

Selfie _s(String id, String from, DateTime at, {DateTime? seen}) => Selfie(
      id: id,
      from: from,
      bytes: Uint8List(0),
      createdAt: at,
      seenAt: seen,
    );

void main() {
  final now = DateTime(2026, 10, 10, 15, 0);

  test('counts only my selfies sent today', () {
    final all = [
      _s('1', 'me', DateTime(2026, 10, 10, 8, 0)),
      _s('2', 'me', DateTime(2026, 10, 10, 9, 0)),
      _s('3', 'me', DateTime(2026, 10, 9, 23, 59)),
      _s('4', 'you', DateTime(2026, 10, 10, 10, 0)),
    ];
    expect(sentToday(all, 'me', now), 2);
  });

  test('only my selfies older than a week expire', () {
    final all = [
      _s('old-me', 'me', now.subtract(const Duration(days: 8))),
      _s('new-me', 'me', now.subtract(const Duration(days: 2))),
      _s('old-you', 'you', now.subtract(const Duration(days: 9))),
    ];
    expect(expiredOwn(all, 'me', now).map((s) => s.id), ['old-me']);
  });

  test('clock label uses 12 hour time', () {
    expect(clockLabel(DateTime(2026, 1, 1, 0, 5)), '12:05 AM');
    expect(clockLabel(DateTime(2026, 1, 1, 7, 42)), '7:42 AM');
    expect(clockLabel(DateTime(2026, 1, 1, 12, 0)), '12:00 PM');
    expect(clockLabel(DateTime(2026, 1, 1, 23, 9)), '11:09 PM');
  });

  test('caption joins name and time', () {
    expect(captionFor('Asha', DateTime(2026, 1, 1, 7, 42)), 'Asha · 7:42 AM');
  });
}
