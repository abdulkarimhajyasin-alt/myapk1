import 'package:expense_network/utils/money_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses valid positive money values to cents', () {
    expect(MoneyUtils.parseToCents('20'), 2000);
    expect(MoneyUtils.parseToCents('20.5'), 2050);
    expect(MoneyUtils.parseToCents('20.55'), 2055);
    expect(MoneyUtils.parseToCents('20,55'), 2055);
  });

  test('rejects invalid or non-positive money values', () {
    expect(MoneyUtils.parseToCents(''), isNull);
    expect(MoneyUtils.parseToCents('0'), isNull);
    expect(MoneyUtils.parseToCents('-5'), isNull);
    expect(MoneyUtils.parseToCents('10.999'), isNull);
  });

  test('formats money with currency symbols and negative values', () {
    expect(MoneyUtils.formatCents(2055, currencySymbol: '€'), '€ 20.55');
    expect(MoneyUtils.formatCents(-2055, currencySymbol: '€'), '-€ 20.55');
    expect(MoneyUtils.formatCents(123456, currencySymbol: 'ر.س'), 'ر.س 1234.56');
  });
}
