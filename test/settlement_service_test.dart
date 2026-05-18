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

  test('member balances expose owes receives and settled states', () {
    final network = ExpenseNetwork(
      name: 'Trip',
      password: 'secret',
      createdAt: DateTime(2026),
      members: [
        Member(
          name: 'Receiver',
          expenses: [
            Expense(amountCents: 9000, createdAt: DateTime(2026)),
          ],
        ),
        Member(name: 'Ower'),
        Member(
          name: 'Settled',
          expenses: [
            Expense(amountCents: 4500, createdAt: DateTime(2026)),
          ],
        ),
      ],
    );

    final settlement = const SettlementService().calculate(network);
    final byName = {
      for (final member in settlement.members) member.memberName: member,
    };

    expect(byName['Receiver']!.paidCents, 9000);
    expect(byName['Receiver']!.shouldPayCents, 4500);
    expect(byName['Receiver']!.balanceCents, 4500);
    expect(byName['Ower']!.balanceCents, -4500);
    expect(byName['Settled']!.balanceCents, 0);
  });
}
