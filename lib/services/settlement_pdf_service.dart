import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../l10n/app_localizations.dart';
import '../models/expense_network.dart';
import '../models/settlement.dart';
import '../utils/money_utils.dart';

class SettlementPdfService {
  const SettlementPdfService();

  Future<Uint8List> buildPdf({
    required ExpenseNetwork network,
    required NetworkSettlement settlement,
    required AppLocalizations l10n,
    required DateTime generatedAt,
  }) async {
    final document = pw.Document();
    final isArabic = l10n.locale.languageCode == 'ar';
    final direction = isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr;

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: direction,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Text(
            l10n.appTitle,
            style: pw.TextStyle(
              fontSize: 22,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text('${l10n.networkName}: ${network.name}'),
          pw.Text('${l10n.networkCurrency}: ${network.currencyCode}'),
          pw.Text('${l10n.generatedAt}: ${_formatDateTime(generatedAt)}'),
          pw.SizedBox(height: 18),
          _sectionTitle(l10n.totalExpenses),
          pw.Text(
            MoneyUtils.formatCents(
              settlement.totalCents,
              currencySymbol: network.currencySymbol,
            ),
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 16),
          _sectionTitle(l10n.memberStatus),
          pw.TableHelper.fromTextArray(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            headers: [
              l10n.members,
              l10n.paid,
              l10n.shouldPay,
              l10n.balance,
            ],
            data: settlement.members.map((member) {
              return [
                member.memberName,
                MoneyUtils.formatCents(
                  member.paidCents,
                  currencySymbol: network.currencySymbol,
                ),
                MoneyUtils.formatCents(
                  member.shouldPayCents,
                  currencySymbol: network.currencySymbol,
                ),
                MoneyUtils.formatCents(
                  member.balanceCents,
                  currencySymbol: network.currencySymbol,
                ),
              ];
            }).toList(),
            cellAlignment:
                isArabic ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
          ),
          pw.SizedBox(height: 16),
          _sectionTitle(l10n.finalSettlement),
          if (settlement.payments.isEmpty)
            pw.Text(l10n.noSettlementNeeded)
          else
            ...settlement.payments.map(
              (payment) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 6),
                child: pw.Text(
                  l10n.settlementPayment(
                    fromMember: payment.fromMember,
                    amount: MoneyUtils.formatCents(
                      payment.amountCents,
                      currencySymbol: network.currencySymbol,
                    ),
                    toMember: payment.toMember,
                  ),
                ),
              ),
            ),
          pw.SizedBox(height: 24),
          pw.Divider(color: PdfColors.grey400),
          pw.Text(l10n.footerText, style: const pw.TextStyle(fontSize: 9)),
          pw.Text('Karamix Labs', style: const pw.TextStyle(fontSize: 9)),
        ],
      ),
    );

    return document.save();
  }

  Future<void> sharePdf({
    required ExpenseNetwork network,
    required NetworkSettlement settlement,
    required AppLocalizations l10n,
    DateTime? generatedAt,
  }) async {
    final bytes = await buildPdf(
      network: network,
      settlement: settlement,
      l10n: l10n,
      generatedAt: generatedAt ?? DateTime.now(),
    );
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'settlement-${network.name}.pdf',
    );
  }

  pw.Widget _sectionTitle(String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Text(
        value,
        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
}
