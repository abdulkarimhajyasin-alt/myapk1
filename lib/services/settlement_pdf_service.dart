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

  static const pdfRegularFontAsset = 'assets/fonts/Amiri-Regular.ttf';
  static const pdfBoldFontAsset = 'assets/fonts/Amiri-Bold.ttf';
  static const requiredPdfGlyphs =
      'Maskan Karamix Labs Powered by 0123456789/.:,-€©'
      'تقرير مصاريف السكن معلومات الشبكة وقت الإنشاء العملة عدد الأعضاء'
      'إجمالي المصاريف حصة كل عضو تسوية الأعضاء تعليمات التسوية'
      'الجميع متوازنون لا توجد تحويلات مطلوبة عليه له يدفع إلى';
  static const requiredPdfPresentationGlyphs = <int>[
    0xfe8d,
    0xfe91,
    0xfeae,
    0xfedf,
    0xfee2,
    0xfef2,
  ];

  Future<Uint8List> buildPdf({
    required ExpenseNetwork network,
    required NetworkSettlement settlement,
    required AppLocalizations l10n,
    required DateTime generatedAt,
  }) async {
    final regularFont = pw.Font.ttf(
      await rootBundle.load(pdfRegularFontAsset),
    );
    final boldFont = pw.Font.ttf(
      await rootBundle.load(pdfBoldFontAsset),
    );
    final logoBytes = await _loadOptionalAsset('assets/icons/app_icon.png');
    final logo = logoBytes == null ? null : pw.MemoryImage(logoBytes);
    final copy = _PdfCopy(isArabic: l10n.locale.languageCode == 'ar');
    final pdfTheme = _SettlementPdfTheme(
      regularFont: regularFont,
      boldFont: boldFont,
      textDirection:
          copy.isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
    );
    final document = pw.Document(
      theme: pdfTheme.themeData,
    );

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(34, 30, 34, 28),
        textDirection: pdfTheme.textDirection,
        footer: (context) => _footer(
          copy: copy,
          pdfTheme: pdfTheme,
          generatedAt: generatedAt,
          page: context.pageNumber,
          pages: context.pagesCount,
        ),
        build: (context) => [
          _header(copy: copy, pdfTheme: pdfTheme, logo: logo),
          pw.SizedBox(height: 18),
          _networkInfo(
            copy: copy,
            pdfTheme: pdfTheme,
            network: network,
            generatedAt: generatedAt,
          ),
          pw.SizedBox(height: 14),
          _totalCard(
            copy: copy,
            pdfTheme: pdfTheme,
            network: network,
            settlement: settlement,
          ),
          pw.SizedBox(height: 16),
          _memberTable(
            copy: copy,
            pdfTheme: pdfTheme,
            network: network,
            settlement: settlement,
          ),
          pw.SizedBox(height: 16),
          _settlementInstructions(
            copy: copy,
            pdfTheme: pdfTheme,
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
    required _SettlementPdfTheme pdfTheme,
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
              crossAxisAlignment: pdfTheme.start,
              children: [
                _pdfText(
                  'Maskan',
                  pdfTheme: pdfTheme,
                  textAlign: pdfTheme.startAlign,
                  style: pdfTheme.style(
                    color: PdfColors.white,
                    fontSize: 26,
                    isBold: true,
                  ),
                ),
                pw.SizedBox(height: 4),
                _pdfText(
                  copy.subtitle,
                  pdfTheme: pdfTheme,
                  textAlign: pdfTheme.startAlign,
                  style: pdfTheme.style(
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
    required _SettlementPdfTheme pdfTheme,
    required ExpenseNetwork network,
    required DateTime generatedAt,
  }) {
    return _sectionCard(
      title: copy.networkInfo,
      pdfTheme: pdfTheme,
      child: pw.Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _infoTile(copy.networkName, network.name, pdfTheme),
          _infoTile(
            copy.generatedAt,
            _PdfTextFormatter.formatDateTime(generatedAt),
            pdfTheme,
          ),
          _infoTile(copy.currency, network.currencyCode, pdfTheme),
          _infoTile(
            copy.memberCount,
            network.members.length.toString(),
            pdfTheme,
          ),
        ],
      ),
    );
  }

  pw.Widget _totalCard({
    required _PdfCopy copy,
    required _SettlementPdfTheme pdfTheme,
    required ExpenseNetwork network,
    required NetworkSettlement settlement,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(18),
      decoration: _cardDecoration(PdfColors.blue50),
      child: pw.Column(
        crossAxisAlignment: pdfTheme.start,
        children: [
          _pdfText(
            copy.totalExpenses,
            pdfTheme: pdfTheme,
            textAlign: pdfTheme.startAlign,
            style: pdfTheme.style(color: PdfColors.blueGrey700),
          ),
          pw.SizedBox(height: 6),
          _pdfText(
            _PdfTextFormatter.formatCurrency(
              settlement.totalCents,
              currencySymbol: network.currencySymbol,
              isArabic: copy.isArabic,
            ),
            pdfTheme: pdfTheme,
            textAlign: pdfTheme.startAlign,
            style: pdfTheme.style(
              color: PdfColors.blue900,
              fontSize: 28,
              isBold: true,
            ),
          ),
          pw.SizedBox(height: 4),
          _pdfText(
            copy.labeledValue(
              copy.sharePerMember,
              _PdfTextFormatter.formatCurrency(
                settlement.sharePerMemberCents,
                currencySymbol: network.currencySymbol,
                isArabic: copy.isArabic,
              ),
            ),
            pdfTheme: pdfTheme,
            textAlign: pdfTheme.startAlign,
            style: pdfTheme.style(
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
    required _SettlementPdfTheme pdfTheme,
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
          _tableCell(member.memberName, pdfTheme: pdfTheme, isBold: true),
          _tableCell(
            _PdfTextFormatter.formatCurrency(
              member.paidCents,
              currencySymbol: network.currencySymbol,
              isArabic: copy.isArabic,
            ),
            pdfTheme: pdfTheme,
          ),
          _tableCell(
            _PdfTextFormatter.formatCurrency(
              member.shouldPayCents,
              currencySymbol: network.currencySymbol,
              isArabic: copy.isArabic,
            ),
            pdfTheme: pdfTheme,
          ),
          _tableCell(
            _memberBalanceStatus(
              copy: copy,
              balanceCents: member.balanceCents,
              currencySymbol: network.currencySymbol,
            ),
            pdfTheme: pdfTheme,
            isBold: true,
          ),
        ],
      );
    });

    return _sectionCard(
      title: copy.memberStatus,
      pdfTheme: pdfTheme,
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
                    pdfTheme: pdfTheme,
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
    required _SettlementPdfTheme pdfTheme,
    required ExpenseNetwork network,
    required NetworkSettlement settlement,
  }) {
    return _sectionCard(
      title: copy.settlementInstructions,
      pdfTheme: pdfTheme,
      child: settlement.payments.isEmpty
          ? _instructionTile(copy.noSettlementNeeded, pdfTheme)
          : pw.Column(
              children: settlement.payments
                  .map(
                    (payment) => _instructionTile(
                      copy.paymentText(
                        fromMember: payment.fromMember,
                        amount: _PdfTextFormatter.formatCurrency(
                          payment.amountCents,
                          currencySymbol: network.currencySymbol,
                          isArabic: copy.isArabic,
                        ),
                        toMember: payment.toMember,
                      ),
                      pdfTheme,
                    ),
                  )
                  .toList(),
            ),
    );
  }

  pw.Widget _sectionCard({
    required String title,
    required _SettlementPdfTheme pdfTheme,
    required pw.Widget child,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(16),
      decoration: _cardDecoration(PdfColors.white),
      child: pw.Column(
        crossAxisAlignment: pdfTheme.start,
        children: [
          _pdfText(
            title,
            pdfTheme: pdfTheme,
            textAlign: pdfTheme.startAlign,
            style: pdfTheme.style(
              color: PdfColors.blueGrey900,
              fontSize: 15,
              isBold: true,
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

  pw.Widget _infoTile(
    String label,
    String value,
    _SettlementPdfTheme pdfTheme,
  ) {
    return pw.Container(
      width: 234,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.blueGrey50,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pdfTheme.start,
        children: [
          _pdfText(
            label,
            pdfTheme: pdfTheme,
            textAlign: pdfTheme.startAlign,
            style: pdfTheme.style(
              color: PdfColors.blueGrey600,
              fontSize: 9,
            ),
          ),
          pw.SizedBox(height: 3),
          _pdfText(
            value,
            pdfTheme: pdfTheme,
            textAlign: pdfTheme.startAlign,
            style: pdfTheme.style(
              color: PdfColors.blueGrey900,
              fontSize: 12,
              isBold: true,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _tableCell(
    String value, {
    required _SettlementPdfTheme pdfTheme,
    bool isHeader = false,
    bool isBold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 9, horizontal: 8),
      child: _pdfText(
        value,
        pdfTheme: pdfTheme,
        textAlign: pdfTheme.startAlign,
        style: pdfTheme.style(
          color: isHeader ? PdfColors.white : PdfColors.blueGrey900,
          fontSize: isHeader ? 10 : 9.5,
          isBold: isBold,
          lineSpacing: 2,
        ),
      ),
    );
  }

  pw.Widget _instructionTile(
    String value,
    _SettlementPdfTheme pdfTheme,
  ) {
    return pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.only(bottom: 8),
      padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: pw.BoxDecoration(
        color: PdfColors.green50,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.green200, width: 0.6),
      ),
      child: _pdfText(
        value,
        pdfTheme: pdfTheme,
        textAlign: pdfTheme.startAlign,
        style: pdfTheme.style(
          color: PdfColors.green900,
          fontSize: 11,
          isBold: true,
          lineSpacing: 2,
        ),
      ),
    );
  }

  pw.Widget _footer({
    required _PdfCopy copy,
    required _SettlementPdfTheme pdfTheme,
    required DateTime generatedAt,
    required int page,
    required int pages,
  }) {
    final year = generatedAt.toLocal().year.toString();
    final timestamp = _PdfTextFormatter.formatDateTime(generatedAt);
    return pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Divider(color: PdfColors.blueGrey100, height: 1),
        pw.SizedBox(height: 6),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            _pdfText(
              'Maskan © $year',
              pdfTheme: pdfTheme,
              textAlign: pdfTheme.startAlign,
              style: pdfTheme.style(
                color: PdfColors.blueGrey600,
                fontSize: 8,
              ),
            ),
            pw.SizedBox(width: 12),
            pw.Expanded(
              child: _pdfText(
                copy.footerText(
                  generatedAt: timestamp,
                  page: page,
                  pages: pages,
                ),
                pdfTheme: pdfTheme,
                textAlign: pdfTheme.endAlign,
                style: pdfTheme.style(
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
        _PdfTextFormatter.formatCurrency(
          -balanceCents,
          currencySymbol: currencySymbol,
          isArabic: copy.isArabic,
        ),
      );
    }
    if (balanceCents > 0.5) {
      return copy.shouldReceive(
        _PdfTextFormatter.formatCurrency(
          balanceCents,
          currencySymbol: currencySymbol,
          isArabic: copy.isArabic,
        ),
      );
    }
    return copy.settled;
  }
}

pw.Text _pdfText(
  String value, {
  required _SettlementPdfTheme pdfTheme,
  required pw.TextStyle style,
  pw.TextAlign? textAlign,
}) {
  return pw.Text(
    value,
    textDirection: pdfTheme.textDirection,
    textAlign: textAlign,
    style: style,
  );
}

class _SettlementPdfTheme {
  const _SettlementPdfTheme({
    required this.regularFont,
    required this.boldFont,
    required this.textDirection,
  });

  final pw.Font regularFont;
  final pw.Font boldFont;
  final pw.TextDirection textDirection;

  pw.ThemeData get themeData => pw.ThemeData.withFont(
        base: regularFont,
        bold: boldFont,
        fontFallback: [regularFont],
      );

  pw.CrossAxisAlignment get start => textDirection == pw.TextDirection.rtl
      ? pw.CrossAxisAlignment.end
      : pw.CrossAxisAlignment.start;

  pw.TextAlign get startAlign => textDirection == pw.TextDirection.rtl
      ? pw.TextAlign.right
      : pw.TextAlign.left;

  pw.TextAlign get endAlign => textDirection == pw.TextDirection.rtl
      ? pw.TextAlign.left
      : pw.TextAlign.right;

  pw.TextStyle style({
    required PdfColor color,
    double? fontSize,
    bool isBold = false,
    double? lineSpacing,
  }) {
    return pw.TextStyle(
      font: isBold ? boldFont : regularFont,
      fontBold: boldFont,
      fontFallback: [regularFont],
      color: color,
      fontSize: fontSize,
      fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
      lineSpacing: lineSpacing,
    );
  }
}

class _PdfTextFormatter {
  const _PdfTextFormatter._();

  static String formatCurrency(
    num cents, {
    required String currencySymbol,
    required bool isArabic,
  }) {
    final isNegative = cents < 0;
    final amount = (cents.abs() / 100).toStringAsFixed(2);
    final sign = isNegative ? '-' : '';
    final symbol = currencySymbol.trim().isEmpty ? r'$' : currencySymbol.trim();

    if (isArabic) {
      return '$sign$amount $symbol';
    }

    return MoneyUtils.formatCents(cents, currencySymbol: symbol);
  }

  static String formatDateTime(DateTime value) {
    final local = value.toLocal();
    return '${local.year.toString().padLeft(4, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
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
  String get subtitle => isArabic
      ? '$arabicSubtitle | $englishSubtitle'
      : '$englishSubtitle | $arabicSubtitle';
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

  String labeledValue(String label, String value) => '$label: $value';

  String footerText({
    required String generatedAt,
    required int page,
    required int pages,
  }) {
    return '$poweredBy | $generatedAt | $page/$pages';
  }

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
