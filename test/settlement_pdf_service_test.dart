import 'package:expense_network/l10n/app_localizations.dart';
import 'package:expense_network/models/expense.dart';
import 'package:expense_network/models/expense_network.dart';
import 'package:expense_network/models/member.dart';
import 'package:expense_network/services/settlement_pdf_service.dart';
import 'package:expense_network/services/settlement_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('builds a non-empty settlement PDF including empty settlement state',
      () async {
    final network = ExpenseNetwork(
      name: 'Flat',
      password: 'network',
      createdAt: DateTime(2026),
      members: [
        Member(name: 'Ali'),
        Member(name: 'Mona'),
      ],
    );
    final settlement = const SettlementService().calculate(network);

    final bytes = await const SettlementPdfService().buildPdf(
      network: network,
      settlement: settlement,
      l10n: const AppLocalizations(Locale('en')),
      generatedAt: DateTime(2026, 5, 17, 12, 30),
    );

    expect(settlement.payments, isEmpty);
    expect(bytes.length, greaterThan(500));
  });

  test('builds a non-empty PDF when transfers are required', () async {
    final network = ExpenseNetwork(
      name: 'Flat',
      password: 'network',
      createdAt: DateTime(2026),
      members: [
        Member(
          name: 'Ali',
          expenses: [
            Expense(amountCents: 6000, createdAt: DateTime(2026)),
          ],
        ),
        Member(name: 'Mona'),
      ],
    );
    final settlement = const SettlementService().calculate(network);

    final bytes = await const SettlementPdfService().buildPdf(
      network: network,
      settlement: settlement,
      l10n: const AppLocalizations(Locale('en')),
      generatedAt: DateTime(2026, 5, 17, 12, 30),
    );

    expect(settlement.payments, hasLength(1));
    expect(bytes.length, greaterThan(500));
  });
}
