import 'id_utils.dart';

/// Legacy compatibility utility retained for local-data migration only.
///
/// Cloud credential creation and verification must never use this fast hash;
/// those operations are authoritative only in the Phase 2 server function.
class PasswordHashUtils {
  const PasswordHashUtils._();

  static String createHash(String password, String salt) {
    return _fnvHash('$salt:${password.trim()}');
  }

  static bool matches({
    required String password,
    required String salt,
    required String passwordHash,
  }) {
    return createHash(password, salt) == passwordHash;
  }

  static String createSalt(String seed) {
    return IdUtils.legacyId(
        'salt', '$seed-${DateTime.now().toIso8601String()}');
  }

  static String _fnvHash(String value) {
    const offset = 0xcbf29ce484222325;
    const prime = 0x100000001b3;
    var hash = offset;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * prime) & 0x7fffffffffffffff;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }
}
