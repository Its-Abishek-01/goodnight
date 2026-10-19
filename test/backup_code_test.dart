import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:goodnight/features/backup/backup_code.dart';

void main() {
  test('codes are 20 readable characters', () {
    final code = BackupCode.generate(Random(1));
    expect(code.length, 20);
    expect(code.split('').every(BackupCode.alphabet.contains), isTrue);
    expect(BackupCode.generate(Random(2)), isNot(code));
  });

  test('format groups by four and normalize undoes it', () {
    const code = 'K7WDM3QX9PRTH2FNB6YC';
    expect(BackupCode.format(code), 'K7WD-M3QX-9PRT-H2FN-B6YC');
    expect(BackupCode.normalize(' k7wd-m3qx 9prt-h2fn-b6yc '), code);
    expect(BackupCode.normalize(BackupCode.qrData(code)), code);
  });

  test('normalize rejects anything that is not a whole code', () {
    expect(BackupCode.normalize('K7WD-M3QX'), isNull);
    expect(BackupCode.normalize('K7WD-M3QX-9PRT-H2FN-B6Y0'), isNull); // 0 is never used
    expect(BackupCode.normalize(''), isNull);
  });

  test('the code splits into a hidden login and password', () {
    const code = 'K7WDM3QX9PRTH2FNB6YC';
    expect(BackupCode.email(code), 'gn-k7wdm3qx@backup.goodnight.app');
    expect(BackupCode.password(code), '9PRTH2FNB6YC');
  });
}
