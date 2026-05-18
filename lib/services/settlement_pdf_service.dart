import 'package:flutter/services.dart';
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
    final regularFont = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoNaskhArabic-Regular.ttf'),
    );
    final boldFont = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoNaskhArabic-Bold.ttf'),
    );
    final logoBytes = await _loadOptionalAsset('assets/icons/app_icon.png');
    final logo = logoBytes == null ? null : pw.MemoryImage(logoBytes);
    final copy = _PdfCopy(isArabic: l10n.locale.languageCode == 'ar');
    final document = pw.Document(
      theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
    );
    final textDirection =
        copy.isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr;

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(34, 30, 34, 28),
        textDirection: textDirection,
        footer: (context) => _footer(
          copy: copy,
          generatedAt: generatedAt,
          page: context.pageNumber,
          pages: context.pagesCount,
        ),
        build: (context) => [
          _header(copy: copy, logo: logo),
          pw.SizedBox(height: 18),
          _networkInfo(
            copy: copy,
            network: network,
            generatedAt: generatedAt,
          ),
          pw.SizedBox(height: 14),
          _totalCard(
            copy: copy,
            network: network,
            settlement: settlement,
          ),
          pw.SizedBox(height: 16),
          _memberTable(
            copy: copy,
            network: network,
            settlement: settlement,
          ),
          pw.SizedBox(height: 16),
          _settlementInstructions(
            copy: copy,
            network: network,
            settlement: settlement,
          ),
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

  Future<Uint8List?> _loadOptionalAsset(String path) async {
    try {
      final data = await rootBundle.load(path);
      return data.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  pw.Widget _header({
    required _PdfCopy copy,
    required pw.MemoryImage? logo,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(18),
      decoration: _cardDecoration(PdfColors.blueGrey900),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          if (logo != null) ...[
            pw.Container(
              width: 48,
              height: 48,
              padding: const pw.EdgeInsets.all(6),
              decoration: pw.BoxDecoration(
                color: PdfColors.white,
                borderRadius: pw.BorderRadius.circular(12),
              ),
              child: pw.Image(logo),
            ),
            pw.SizedBox(width: 14),
          ],
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Maskan',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 26,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  '${copy.englishSubtitle} | ${copy.arabicSubtitle}',
                  style: const pw.TextStyle(
                    color: PdfColors.blueGrey100,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _networkInfo({
    required _PdfCopy copy,
    required ExpenseNetwork network,
    required DateTime generatedAt,
  }) {
    return _sectionCard(
      title: copy.networkInfo,
      child: pw.Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _infoTile(copy.networkName, network.name),
          _infoTile(copy.generatedAt, _formatDateTime(generatedAt)),
          _infoTile(copy.currency, network.currencyCode),
          _infoTile(copy.memberCount, network.members.length.toString()),
        ],
      ),
    );
  }

  pw.Widget _totalCard({
    required _PdfCopy copy,
    required ExpenseNetwork network,
    required NetworkSettlement settlement,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(18),
      decoration: _cardDecoration(PdfColors.blue50),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            copy.totalExpenses,
            style: const pw.TextStyle(color: PdfColors.blueGrey700),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            MoneyUtils.formatCents(
              settlement.totalCents,
              currencySymbol: network.currencySymbol,
            ),
            style: pw.TextStyle(
              color: PdfColors.blue900,
              fontSize: 28,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            '${copy.sharePerMember}: ${MoneyUtils.formatCents(
              settlement.sharePerMemberCents,
              currencySymbol: network.currencySymbol,
            )}',
            style: const pw.TextStyle(
              color: PdfColors.blueGrey700,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _memberTable({
    required _PdfCopy copy,
    required ExpenseNetwork network,
    required NetworkSettlement settlement,
  }) {
    final headers = [
      copy.member,
      copy.paid,
      copy.fairShare,
      copy.result,
    ];
    final rows = settlement.members.asMap().entries.map((entry) {
      final member = entry.value;
      return pw.TableRow(
        decoration: pw.BoxDecoration(
          color: entry.key.isEven ? PdfColors.white : PdfColors.blueGrey50,
        ),
        children: [
          _tableCell(member.memberName, isBold: true),
          _tableCell(
            MoneyUtils.formatCents(
              member.paidCents,
              currencySymbol: network.currencySymbol,
            ),
          ),
          _tableCell(
            MoneyUtils.formatCents(
              member.shouldPayCents,
              currencySymbol: network.currencySymbol,
            ),
          ),
          _tableCell(
            _memberBalanceStatus(
              copy: copy,
              balanceCents: member.balanceCents,
              currencySymbol: network.currencySymbol,
            ),
            isBold: true,
          ),
        ],
      );
    });

    return _sectionCard(
      title: copy.memberStatus,
      child: pw.Table(
        border: pw.TableBorder(
          horizontalInside: const pw.BorderSide(
            color: PdfColors.blueGrey100,
            width: 0.6,
          ),
        ),
        columnWidths: const {
          0: pw.FlexColumnWidth(1.5),
          1: pw.FlexColumnWidth(),
          2: pw.FlexColumnWidth(),
          3: pw.FlexColumnWidth(1.4),
        },
        children: [
          pw.TableRow(
            decoration: pw.BoxDecoration(
              color: PdfColors.blueGrey900,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            children: headers
                .map(
                  (header) => _tableCell(
                    header,
                    isHeader: true,
                    isBold: true,
                  ),
                )
                .toList(),
          ),
          ...rows,
        ],
      ),
    );
  }

  pw.Widget _settlementInstructions({
    required _PdfCopy copy,
    required ExpenseNetwork network,
    required NetworkSettlement settlement,
  }) {
    return _sectionCard(
      title: copy.settlementInstructions,
      child: settlement.payments.isEmpty
          ? _instructionTile(copy.noSettlementNeeded)
          : pw.Column(
              children: settlement.payments
                  .map(
                    (payment) => _instructionTile(
                      copy.paymentText(
                        fromMember: payment.fromMember,
                        amount: MoneyUtils.formatCents(
                          payment.amountCents,
                          currencySymbol: network.currencySymbol,
                        ),
                        toMember: payment.toMember,
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  pw.Widget _sectionCard({
    required String title,
    required pw.Widget child,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(16),
      decoration: _cardDecoration(PdfColors.white),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              color: PdfColors.blueGrey900,
              fontSize: 15,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  pw.BoxDecoration _cardDecoration(PdfColor color) {
    return pw.BoxDecoration(
      color: color,
      borderRadius: pw.BorderRadius.circular(10),
      border: pw.Border.all(color: PdfColors.blueGrey100, width: 0.6),
    );
  }

  pw.Widget _infoTile(String label, String value) {
    return pw.Container(
      width: 234,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.blueGrey50,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(
              color: PdfColors.blueGrey600,
              fontSize: 9,
            ),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            value,
            style: pw.TextStyle(
              color: PdfColors.blueGrey900,
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _tableCell(
    String value, {
    bool isHeader = false,
    bool isBold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 9, horizontal: 8),
      child: pw.Text(
        value,
        style: pw.TextStyle(
          color: isHeader ? PdfColors.white : PdfColors.blueGrey900,
          fontSize: isHeader ? 10 : 9.5,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          lineSpacing: 2,
        ),
      ),
    );
  }

  pw.Widget _instructionTile(String value) {
    return pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.only(bottom: 8),
      padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: pw.BoxDecoration(
        color: PdfColors.green50,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.green200, width: 0.6),
      ),
      child: pw.Text(
        value,
        style: pw.TextStyle(
          color: PdfColors.green900,
          fontSize: 11,
          fontWeight: pw.FontWeight.bold,
          lineSpacing: 2,
        ),
      ),
    );
  }

  pw.Widget _footer({
    required _PdfCopy copy,
    required DateTime generatedAt,
    required int page,
    required int pages,
  }) {
    final year = generatedAt.toLocal().year.toString();
    return pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Divider(color: PdfColors.blueGrey100, height: 1),
        pw.SizedBox(height: 6),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Maskan © $year',
              style: const pw.TextStyle(
                color: PdfColors.blueGrey600,
                fontSize: 8,
              ),
            ),
            pw.SizedBox(width: 12),
            pw.Expanded(
              child: pw.Text(
                '${copy.poweredBy} | ${copy.generatedAt}: '
                '${_formatDateTime(generatedAt)} | $page/$pages',
                textAlign: pw.TextAlign.right,
                style: const pw.TextStyle(
                  color: PdfColors.blueGrey600,
                  fontSize: 8,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _memberBalanceStatus({
    required _PdfCopy copy,
    required double balanceCents,
    required String currencySymbol,
  }) {
    if (balanceCents < -0.5) {
      return copy.owes(
        MoneyUtils.formatCents(-balanceCents, currencySymbol: currencySymbol),
      );
    }
    if (balanceCents > 0.5) {
      return copy.shouldReceive(
        MoneyUtils.formatCents(balanceCents, currencySymbol: currencySymbol),
      );
    }
    return copy.settled;
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

class _PdfCopy {
  const _PdfCopy({required this.isArabic});

  final bool isArabic;

  String get englishSubtitle => 'Shared Housing Expense Report';
  String get arabicSubtitle => 'تقرير مصاريف السكن';
  String get networkInfo => isArabic ? 'معلومات الشبكة' : 'Network info';
  String get networkName => isArabic ? 'اسم الشبكة' : 'Network name';
  String get generatedAt => isArabic ? 'وقت الإنشاء' : 'Generated at';
  String get currency => isArabic ? 'العملة' : 'Currency';
  String get memberCount => isArabic ? 'عدد الأعضاء' : 'Member count';
  String get totalExpenses => isArabic ? 'إجمالي المصاريف' : 'Total expenses';
  String get sharePerMember => isArabic ? 'حصة كل عضو' : 'Fair share';
  String get memberStatus => isArabic ? 'تسوية الأعضاء' : 'Member settlement';
  String get member => isArabic ? 'العضو' : 'Member';
  String get paid => isArabic ? 'دفع' : 'Paid';
  String get fairShare => isArabic ? 'الحصة' : 'Fair share';
  String get result => isArabic ? 'النتيجة' : 'Result';
  String get settlementInstructions =>
      isArabic ? 'تعليمات التسوية' : 'Settlement instructions';
  String get noSettlementNeeded =>
      isArabic ? 'الجميع متوازنون، لا توجد تحويلات مطلوبة.' : 'Everyone is settled.';
  String get settled => isArabic ? 'متوازن' : 'Settled';
  String get poweredBy =>
      isArabic ? 'بدعم من Karamix Labs' : 'Powered by Karamix Labs';

  String owes(String amount) => isArabic ? 'عليه $amount' : 'Owes $amount';

  String shouldReceive(String amount) =>
      isArabic ? 'له $amount' : 'Should receive $amount';

  String paymentText({
    required String fromMember,
    required String amount,
    required String toMember,
  }) {
    if (isArabic) {
      return '$fromMember يدفع $amount إلى $toMember';
    }
    return '$fromMember pays $amount to $toMember';
  }
}
