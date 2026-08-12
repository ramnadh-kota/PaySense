import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Salted SHA-256 password hashing for local-only account storage.
///
/// This is not a substitute for a real backend authentication service (no
/// key stretching like bcrypt/argon2), but it ensures plaintext passwords
/// are never written to disk for this local-first app.
class PasswordHasher {
  PasswordHasher._();

  static const int _saltLength = 16;

  /// Generates a cryptographically random salt, hex-encoded.
  static String generateSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(_saltLength, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static String hash(String password, String salt) {
    final bytes = utf8.encode('$salt:$password');
    return sha256.convert(bytes).toString();
  }

  static bool verify(String password, String salt, String expectedHash) {
    return hash(password, salt) == expectedHash;
  }
}
