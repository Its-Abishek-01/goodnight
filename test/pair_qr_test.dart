import 'package:flutter_test/flutter_test.dart';
import 'package:goodnight/features/pairing/pair_repository.dart';

void main() {
  group('codeFromQr', () {
    test('reads the code from our QR payload', () {
      final data = PairRepository.pairQrData('7WED6T');
      expect(PairRepository.codeFromQr(data), '7WED6T');
    });

    test('accepts a bare code, in any case or spacing', () {
      expect(PairRepository.codeFromQr(' 7wed-6t '), '7WED6T');
    });

    test('rejects anything that is not a pair code', () {
      expect(PairRepository.codeFromQr('https://example.com'), isNull);
      expect(PairRepository.codeFromQr('goodnight:pair:ABC'), isNull);
      // 0, O, 1, I and L are never used in codes.
      expect(PairRepository.codeFromQr('ABCDE0'), isNull);
      expect(PairRepository.codeFromQr(''), isNull);
    });
  });
}
