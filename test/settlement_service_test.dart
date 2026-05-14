import 'package:expense_network/models/expense.dart';
import 'package:expense_network/models/expense_network.dart';
import 'package:expense_network/models/member.dart';
import 'package:expense_network/services/settlement_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('calculates payer to receiver settlement', () {
    final network = ExpenseNetwork(
      name: 'Trip',
      password: 'secret',
      createdAt: DateTime(2026),
      members: [
        Member(
          name: 'Ali',
          expenses: [
            Expense(amountCents: 6000, createdAt: DateTime(2026)),
          ],
        ),
        Member(
          name: 'Ahmad',
          expenses: [
            Expense(amountCents: 2000, createdAt: DateTime(2026)),
          ],
        ),
      ],
    );

    final settlement = const SettlementService().calculate(network);

    expect(settlement.totalCents, 8000);
    expect(settlement.sharePerMemberCents, 4000);
    expect(settlement.payments, hasLength(1));
    expect(settlement.payments.single.fromMember, 'Ahmad');
    expect(settlement.payments.single.toMember, 'Ali');
    expect(settlement.payments.single.amountCents, 2000);
  });
}
