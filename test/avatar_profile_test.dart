import 'package:expense_network/models/member.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('old member data loads with generated avatar fields', () {
    final member = Member.fromJson({
      'name': 'Ali Hassan',
      'createdAt': DateTime(2026).toIso8601String(),
      'expenses': [],
    });

    expect(member.avatarInitials, 'AH');
    expect(member.avatarColor, startsWith('#'));
  });

  test('explicit avatar fields are preserved', () {
    final member = Member(
      name: 'Mona',
      avatarColor: '#059669',
      avatarInitials: 'MO',
    );

    expect(member.avatarColor, '#059669');
    expect(member.avatarInitials, 'MO');
  });
}
