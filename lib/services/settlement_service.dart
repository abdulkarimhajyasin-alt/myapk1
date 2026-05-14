import '../models/expense_network.dart';
import '../models/settlement.dart';

class SettlementService {
  const SettlementService();

  NetworkSettlement calculate(ExpenseNetwork network) {
    if (network.members.isEmpty) {
      return const NetworkSettlement(
        totalCents: 0,
        sharePerMemberCents: 0,
        members: [],
        payments: [],
      );
    }

    final totalCents = network.totalExpensesCents;
    final sharePerMemberCents = totalCents / network.members.length;
    final memberSettlements = network.members.map((member) {
      final balance = member.totalPaidCents - sharePerMemberCents;
      return MemberSettlement(
        memberName: member.name,
        paidCents: member.totalPaidCents,
        shouldPayCents: sharePerMemberCents,
        balanceCents: balance,
      );
    }).toList();

    final payers = memberSettlements
        .where((member) => member.balanceCents < -0.5)
        .map((member) => _OpenBalance(member.memberName, -member.balanceCents))
        .toList();
    final receivers = memberSettlements
        .where((member) => member.balanceCents > 0.5)
        .map((member) => _OpenBalance(member.memberName, member.balanceCents))
        .toList();

    final payments = <SettlementPayment>[];
    var payerIndex = 0;
    var receiverIndex = 0;

    while (payerIndex < payers.length && receiverIndex < receivers.length) {
      final payer = payers[payerIndex];
      final receiver = receivers[receiverIndex];
      final amount = payer.amountCents < receiver.amountCents
          ? payer.amountCents
          : receiver.amountCents;

      if (amount > 0.5) {
        payments.add(
          SettlementPayment(
            fromMember: payer.name,
            toMember: receiver.name,
            amountCents: amount,
          ),
        );
      }

      payer.amountCents -= amount;
      receiver.amountCents -= amount;

      if (payer.amountCents <= 0.5) payerIndex++;
      if (receiver.amountCents <= 0.5) receiverIndex++;
    }

    return NetworkSettlement(
      totalCents: totalCents,
      sharePerMemberCents: sharePerMemberCents,
      members: memberSettlements,
      payments: payments,
    );
  }
}

class _OpenBalance {
  _OpenBalance(this.name, this.amountCents);

  final String name;
  double amountCents;
}
