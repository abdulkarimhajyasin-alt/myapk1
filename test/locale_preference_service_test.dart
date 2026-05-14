import 'package:expense_network/l10n/app_localizations.dart';
import 'package:expense_network/services/locale_preference_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('saves selected language locally', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final service = LocalePreferenceService(preferences);

    await service.saveLocale(const Locale('ar'));

    expect(
      preferences.getString(LocalePreferenceService.selectedLocaleKey),
      'ar',
    );
    expect(service.loadLocale(), const Locale('ar'));
  });

  test('invalid saved language falls back to English', () async {
    SharedPreferences.setMockInitialValues({
      LocalePreferenceService.selectedLocaleKey: 'fr',
    });
    final preferences = await SharedPreferences.getInstance();
    final service = LocalePreferenceService(preferences);

    expect(service.loadLocale(), const Locale('en'));
  });

  test('key localized labels exist in English and Arabic', () {
    const english = AppLocalizations(Locale('en'));
    const arabic = AppLocalizations(Locale('ar'));

    expect(english.appTitle, 'Shared Housing Expenses');
    expect(english.createNetwork, 'Create Network');
    expect(english.joinNetwork, 'Join Network');
    expect(english.chooseLanguage, 'Choose your language');
    expect(english.footerText, contains('عبد الكريم حاج ياسين'));
    expect(arabic.appTitle, 'مصروف السكن الجماعي');
    expect(arabic.createNetwork, 'إنشاء شبكة');
    expect(arabic.joinNetwork, 'الانضمام إلى شبكة');
    expect(arabic.chooseLanguage, 'اختر لغة التطبيق');
    expect(arabic.footerText, contains('جميع الحقوق محفوظة'));
  });
}
