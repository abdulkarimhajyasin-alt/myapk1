import 'package:expense_network/l10n/app_localizations.dart';
import 'package:expense_network/models/expense_network.dart';
import 'package:expense_network/models/member.dart';
import 'package:expense_network/screens/add_expense_screen.dart';
import 'package:expense_network/services/expense_network_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class RetryRepository extends Fake implements ExpenseNetworkRepository {
  final ids = <String?>[];
  @override
  Future<ExpenseNetwork> addExpense(
      {required String networkName,
      required String memberName,
      required String addedByMemberId,
      required int amountCents,
      String? note,
      String? clientGeneratedId}) async {
    ids.add(clientGeneratedId);
    throw const RepositoryException('Refresh and retry.',
        code: 'expense_network_busy');
  }
}

void main() {
  testWidgets(
      'Android preserves retry key and changes it only for a different expense',
      (tester) async {
    final repository = RetryRepository();
    final network = ExpenseNetwork(
        name: 'Fixture',
        password: '',
        members: [Member(id: 'm', name: 'Fixture')],
        createdAt: DateTime(2026));
    await tester.pumpWidget(MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AddExpenseScreen(
            repository: repository, network: network, currentMemberId: 'm')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '10');
    Future<void> save() async {
      await tester.ensureVisible(find.byType(FilledButton));
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
    }

    await save();
    await save();
    expect(repository.ids.length, 2);
    expect(repository.ids[0], isNotNull);
    expect(repository.ids[0], repository.ids[1]);
    await tester.enterText(find.byType(TextFormField).first, '11');
    await save();
    expect(repository.ids[2], isNot(repository.ids[1]));
  });
}
