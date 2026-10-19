import 'dart:math';

/// The account backup code, e.g. `K7WD-M3QX-9PRT-H2FN-B6YC`.
///
/// Sign-in is anonymous, so a reinstall would otherwise start a new, empty
/// account. The code is turned into a hidden email/password login linked to
/// the same Firebase account: the first 8 characters name the login, the
/// last 12 are its password (about 99 bits together). No real email is used.
class BackupCode {
  // No 0/O, 1/I/L, so a code is easy to read and type.
  static const alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  static const length = 20;
  static const _idLength = 8;
  static const _domain = 'backup.goodnight.app';
  static const _qrPrefix = 'goodnight:backup:';

  static String generate([Random? random]) {
    final r = random ?? Random.secure();
    return List.generate(length, (_) => alphabet[r.nextInt(alphabet.length)]).join();
  }

  /// Groups of four: `K7WD-M3QX-9PRT-H2FN-B6YC`.
  static String format(String code) => [
        for (var i = 0; i < code.length; i += 4) code.substring(i, min(i + 4, code.length)),
      ].join('-');

  /// Uppercase, without spaces or dashes; null unless it is a whole valid code.
  static String? normalize(String input) {
    var s = input.trim();
    if (s.toLowerCase().startsWith(_qrPrefix)) s = s.substring(_qrPrefix.length);
    s = s.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (s.length != length) return null;
    if (s.split('').any((c) => !alphabet.contains(c))) return null;
    return s;
  }

  static String email(String code) => 'gn-${code.substring(0, _idLength).toLowerCase()}@$_domain';

  static String password(String code) => code.substring(_idLength);

  /// What the backup QR code holds, to scan it from the old phone.
  static String qrData(String code) => '$_qrPrefix$code';
}
