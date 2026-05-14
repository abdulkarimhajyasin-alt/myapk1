class IdUtils {
  const IdUtils._();

  static String createId(String prefix) {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    return '${prefix}_${timestamp}_${_hash(timestamp.toString())}';
  }

  static String legacyId(String prefix, String value) {
    return '${prefix}_legacy_${_hash(value.trim().toLowerCase())}';
  }

  static String _hash(String value) {
    const offset = 0xcbf29ce484222325;
    const prime = 0x100000001b3;
    var hash = offset;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * prime) & 0x7fffffffffffffff;
    }
    return hash.toRadixString(16);
  }
}
