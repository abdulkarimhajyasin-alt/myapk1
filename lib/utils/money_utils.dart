class MoneyUtils {
  const MoneyUtils._();

  static int? parseToCents(String input) {
    final normalized = input.trim().replaceAll(',', '.');
    final match = RegExp(r'^\d+(\.\d{1,2})?$').firstMatch(normalized);
    if (match == null) return null;

    final parts = normalized.split('.');
    final whole = int.tryParse(parts[0]);
    if (whole == null) return null;

    final decimal = parts.length > 1 ? parts[1].padRight(2, '0') : '00';
    final cents = int.tryParse(decimal);
    if (cents == null) return null;

    final total = whole * 100 + cents;
    return total > 0 ? total : null;
  }

  static String formatCents(num cents) {
    return (cents / 100).toStringAsFixed(2);
  }
}
