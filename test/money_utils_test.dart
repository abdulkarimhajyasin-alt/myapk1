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
}
