class MemberSettlement {
  const MemberSettlement({
    required this.memberName,
    required this.paidCents,
    required this.shouldPayCents,
    required this.balanceCents,
  });

  final String memberName;
  final int paidCents;
  final double shouldPayCents;
  final double balanceCents;
}

class SettlementPayment {
  const SettlementPayment({
    required this.fromMember,
    required this.toMember,
    required this.amountCents,
  });

  final String fromMember;
  final String toMember;
  final double amountCents;
}

class NetworkSettlement {
  const NetworkSettlement({
    required this.totalCents,
    required this.sharePerMemberCents,
    required this.members,
    required this.payments,
  });

  final int totalCents;
  final double sharePerMemberCents;
  final List<MemberSettlement> members;
  final List<SettlementPayment> payments;
}
