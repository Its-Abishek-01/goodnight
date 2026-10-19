import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/firebase_providers.dart';
import 'backup_code.dart';

class BackupException implements Exception {
  BackupException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Creates and uses account backup codes (see [BackupCode]).
class BackupService {
  BackupService(this._auth);

  final FirebaseAuth _auth;
  static const _codeKey = 'backup.code';

  /// Whether this account already has a backup code.
  bool get isBackedUp =>
      _auth.currentUser?.providerData.any((p) => p.providerId == EmailAuthProvider.PROVIDER_ID) ?? false;

  /// The code made on this phone, so it can be shown again here.
  Future<String?> savedCode() async => (await SharedPreferences.getInstance()).getString(_codeKey);

  /// Makes a code and links it to this account. A new code replaces the old
  /// one, which stops working.
  Future<String> create() async {
    final user = _auth.currentUser;
    if (user == null) throw BackupException('Not signed in yet. Try again in a moment.');
    try {
      if (isBackedUp) await user.unlink(EmailAuthProvider.PROVIDER_ID);
      final code = BackupCode.generate();
      await user.linkWithCredential(
        EmailAuthProvider.credential(email: BackupCode.email(code), password: BackupCode.password(code)),
      );
      await user.reload();
      await (await SharedPreferences.getInstance()).setString(_codeKey, code);
      return code;
    } on FirebaseAuthException catch (e) {
      throw BackupException(switch (e.code) {
        'operation-not-allowed' => 'Backups are switched off in Firebase (Email/Password sign-in).',
        'network-request-failed' => "Couldn't reach the server. Check your connection.",
        _ => "Couldn't create a backup code (${e.code}).",
      });
    }
  }

  /// Signs this phone into the account the code belongs to.
  Future<void> restore(String input) async {
    final code = BackupCode.normalize(input);
    if (code == null) throw BackupException('That is not a backup code. It has 20 letters and numbers.');
    try {
      await _auth.signInWithEmailAndPassword(email: BackupCode.email(code), password: BackupCode.password(code));
      await (await SharedPreferences.getInstance()).setString(_codeKey, code);
    } on FirebaseAuthException catch (e) {
      throw BackupException(switch (e.code) {
        'user-not-found' || 'wrong-password' || 'invalid-credential' || 'invalid-login-credentials' =>
          "That code doesn't match any backup. Check it and try again.",
        'too-many-requests' => 'Too many tries. Wait a few minutes and try again.',
        'network-request-failed' => "Couldn't reach the server. Check your connection.",
        _ => "Couldn't restore (${e.code}).",
      });
    }
  }
}

final backupServiceProvider = Provider((ref) => BackupService(ref.watch(authProvider)));
