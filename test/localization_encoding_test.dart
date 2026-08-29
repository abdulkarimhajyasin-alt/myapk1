import 'dart:convert';
import 'dart:io';

import 'package:expense_network/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('localization Dart file is UTF-8 without BOM', () {
    final bytes = File('lib/l10n/app_localizations.dart').readAsBytesSync();

    final hasBom = bytes.length >= 3 &&
        bytes[0] == 0xef &&
        bytes[1] == 0xbb &&
        bytes[2] == 0xbf;

    expect(hasBom, isFalse);
    expect(() => utf8.decode(bytes), returnsNormally);
  });

  test('Arabic localization strings are not mojibake', () {
    final source = File('lib/l10n/app_localizations.dart').readAsStringSync();
    const arabic = AppLocalizations(Locale('ar'));
    const english = AppLocalizations(Locale('en'));
    final mojibakeFragments = [
      String.fromCharCode(0x00d8),
      String.fromCharCode(0x00d9),
      String.fromCharCodes([0x0637, 0x00a7]),
      String.fromCharCodes([0x0638, 0x201e]),
      String.fromCharCodes([0x0638, 0x2026]),
      String.fromCharCodes([0x0637, 0x00a3]),
      String.fromCharCodes([0x0637, 0x00a5]),
      String.fromCharCode(0x00e2),
      String.fromCharCodes([0x0622, 0x00a9]),
      String.fromCharCode(0xfffd),
    ];

    for (final fragment in mojibakeFragments) {
      expect(source, isNot(contains(fragment)));
    }

    expect(arabic.arabic, 'العربية');
    expect(arabic.createNetwork, 'إنشاء مصروف');
    expect(arabic.joinNetwork, 'الانضمام إلى مصروف');
    expect(arabic.networkName, 'اسم المصروف');
    expect(arabic.networkPassword, 'كلمة مرور المصروف');
    expect(arabic.networkCurrency, 'عملة المصروف');
    expect(arabic.selectNetwork, 'اختر المصروف');
    expect(arabic.leaveNetwork, 'مغادرة المصروف');
    expect(
      arabic.confirmLeaveNetwork,
      'هل تريد إزالة عضويتك ومغادرة المصروف نهائيًا؟',
    );
    expect(arabic.joinMyMaskanNetwork, 'انضم إلى مصروفي في Maskan:');
    expect(arabic.footerText, contains('عبد الكريم حاج ياسين'));
    expect(english.createNetwork, 'Create Network');
  });
}
