import 'package:expense_network/l10n/app_localizations.dart';
import 'package:expense_network/models/expense.dart';
import 'package:expense_network/models/expense_network.dart';
import 'package:expense_network/models/member.dart';
import 'package:expense_network/services/settlement_pdf_service.dart';
import 'package:expense_network/services/settlement_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  test('builds Arabic settlement PDF with RTL member balance data', () async {
    final l10n = const AppLocalizations(Locale('ar'));
    final network = ExpenseNetwork(
      name: 'السكن',
      password: 'network',
      createdAt: DateTime(2026),
      currencySymbol: 'ر.س',
      members: [
        Member(
          name: 'أحمد',
          expenses: [
            Expense(amountCents: 6000, createdAt: DateTime(2026)),
          ],
        ),
        Member(name: 'مريم'),
      ],
    );
    final settlement = const SettlementService().calculate(network);

    final bytes = await const SettlementPdfService().buildPdf(
      network: network,
      settlement: settlement,
      l10n: l10n,
      generatedAt: DateTime(2026, 5, 17, 12, 30),
    );

    expect(l10n.memberStatus, isNotEmpty);
    expect(l10n.memberOwes('ر.س 30.00'), contains('ر.س 30.00'));
    expect(l10n.memberShouldReceive('ر.س 30.00'), contains('ر.س 30.00'));
    expect(l10n.memberSettled, isNotEmpty);
    expect(
      settlement.members
          .singleWhere((member) => member.memberName == 'أحمد')
          .balanceCents,
      3000,
    );
    expect(bytes.length, greaterThan(500));
  });

  test('Arabic PDF generation accepts RTL names, labels, and euro glyphs',
      () async {
    final network = ExpenseNetwork(
      name: 'بيت كريم',
      password: 'network',
      createdAt: DateTime(2026),
      currencySymbol: '€',
      members: [
        Member(
          name: 'كريم',
          expenses: [
            Expense(amountCents: 37500, createdAt: DateTime(2026)),
          ],
        ),
        Member(name: 'أبو عدي'),
      ],
    );
    final settlement = const SettlementService().calculate(network);

    final bytes = await const SettlementPdfService().buildPdf(
      network: network,
      settlement: settlement,
      l10n: const AppLocalizations(Locale('ar')),
      generatedAt: DateTime(2026, 5, 17, 12, 30),
    );

    expect(network.name, isNot(contains('□')));
    expect(
      network.members.map((member) => member.name).join(),
      isNot(contains('□')),
    );
    expect('له عليه متوازن €', isNot(contains('□')));
    expect(settlement.payments.single.fromMember, 'أبو عدي');
    expect(settlement.payments.single.toMember, 'كريم');
    expect(bytes.length, greaterThan(500));
  });

  test(
      'PDF font contains Arabic, Latin, punctuation, copyright, and euro glyphs',
      () async {
    final regularFontData = await rootBundle.load(
      SettlementPdfService.pdfRegularFontAsset,
    );
    final boldFontData = await rootBundle.load(
      SettlementPdfService.pdfBoldFontAsset,
    );
    final fonts = [
      _readTrueTypeCodePoints(regularFontData),
      _readTrueTypeCodePoints(boldFontData),
    ];

    for (final codePoints in fonts) {
      const requiredPdfGlyphs =
          'Maskan Karamix Labs Powered by 0123456789/.:,-€©'
          'تقرير مصاريف السكن معلومات المصروف وقت الإنشاء العملة عدد الأعضاء'
          'إجمالي المصاريف حصة كل عضو تسوية الأعضاء تعليمات التسوية'
          'الجميع متوازنون لا توجد تحويلات مطلوبة عليه له متوازن يدفع إلى';
      for (final codePoint in requiredPdfGlyphs.runes) {
        if (codePoint == 0x20) continue;
        expect(
          codePoints,
          contains(codePoint),
          reason: 'Missing PDF font glyph for U+${codePoint.toRadixString(16)}',
        );
      }
      for (final codePoint
          in SettlementPdfService.requiredPdfPresentationGlyphs) {
        expect(
          codePoints,
          contains(codePoint),
          reason:
              'Missing shaped Arabic glyph U+${codePoint.toRadixString(16)}',
        );
      }
      for (final codePoint in 'له عليه متوازن €'.runes) {
        if (codePoint == 0x20) continue;
        expect(
          codePoints,
          contains(codePoint),
          reason: 'Missing Arabic settlement/euro glyph '
              'U+${codePoint.toRadixString(16)}',
        );
      }
    }
  });

  test('Arabic settlement PDF embeds Amiri font for strict mobile previews',
      () async {
    final network = ExpenseNetwork(
      name: 'بيت كريم',
      password: 'network',
      createdAt: DateTime(2026),
      currencySymbol: '€',
      members: [
        Member(
          name: 'كريم',
          expenses: [
            Expense(amountCents: 37500, createdAt: DateTime(2026)),
          ],
        ),
        Member(name: 'أبو عدي'),
      ],
    );
    final settlement = const SettlementService().calculate(network);

    final bytes = await const SettlementPdfService().buildPdf(
      network: network,
      settlement: settlement,
      l10n: const AppLocalizations(Locale('ar')),
      generatedAt: DateTime(2026, 5, 18, 12, 30),
    );
    final pdfText = String.fromCharCodes(bytes);

    expect(pdfText, contains('Amiri'));
    expect(bytes.length, greaterThan(500));
  });
}

Set<int> _readTrueTypeCodePoints(ByteData fontData) {
  final bytes = fontData.buffer.asUint8List(
    fontData.offsetInBytes,
    fontData.lengthInBytes,
  );
  final tableCount = _uint16(bytes, 4);
  final tables = <String, int>{};

  for (var i = 0; i < tableCount; i++) {
    final offset = 12 + i * 16;
    final tag = String.fromCharCodes(bytes.sublist(offset, offset + 4));
    tables[tag] = _uint32(bytes, offset + 8);
  }

  final cmapOffset = tables['cmap'];
  if (cmapOffset == null) {
    return const {};
  }

  final codePoints = <int>{};
  final cmapTableCount = _uint16(bytes, cmapOffset + 2);
  for (var i = 0; i < cmapTableCount; i++) {
    final recordOffset = cmapOffset + 4 + i * 8;
    final subtableOffset = cmapOffset + _uint32(bytes, recordOffset + 4);
    final format = _uint16(bytes, subtableOffset);
    if (format == 4) {
      _readFormat4Cmap(bytes, subtableOffset, codePoints);
    } else if (format == 12) {
      _readFormat12Cmap(bytes, subtableOffset, codePoints);
    }
  }

  return codePoints;
}

void _readFormat4Cmap(
  Uint8List bytes,
  int offset,
  Set<int> codePoints,
) {
  final segmentCount = _uint16(bytes, offset + 6) ~/ 2;
  final endCodeOffset = offset + 14;
  final startCodeOffset = endCodeOffset + segmentCount * 2 + 2;

  for (var i = 0; i < segmentCount; i++) {
    final endCode = _uint16(bytes, endCodeOffset + i * 2);
    final startCode = _uint16(bytes, startCodeOffset + i * 2);
    if (endCode == 0xffff) continue;
    for (var codePoint = startCode; codePoint <= endCode; codePoint++) {
      codePoints.add(codePoint);
    }
  }
}

void _readFormat12Cmap(
  Uint8List bytes,
  int offset,
  Set<int> codePoints,
) {
  final groupCount = _uint32(bytes, offset + 12);
  for (var i = 0; i < groupCount; i++) {
    final groupOffset = offset + 16 + i * 12;
    final startCode = _uint32(bytes, groupOffset);
    final endCode = _uint32(bytes, groupOffset + 4);
    for (var codePoint = startCode; codePoint <= endCode; codePoint++) {
      codePoints.add(codePoint);
    }
  }
}

int _uint16(Uint8List bytes, int offset) =>
    ByteData.sublistView(bytes, offset, offset + 2).getUint16(0);

int _uint32(Uint8List bytes, int offset) =>
    ByteData.sublistView(bytes, offset, offset + 4).getUint32(0);
