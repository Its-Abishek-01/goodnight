import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:goodnight/features/pairing/pair_repository.dart';

void main() {
  test('generated codes are 6 readable characters', () {
    final r = Random(1);
    for (var i = 0; i < 200; i++) {
      final code = PairRepository.generateCode(r);
      expect(code, matches(RegExp(r'^[A-HJKMNP-Z2-9]{6}$')));
    }
  });

  test('normalizeCode trims, uppercases and drops separators', () {
    expect(PairRepository.normalizeCode(' ab-c d2e3 '), 'ABCD2E3');
  });
}
