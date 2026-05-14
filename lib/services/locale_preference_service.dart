import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';

class LocalePreferenceService {
  LocalePreferenceService(this._preferences);

  static const selectedLocaleKey = 'selected_locale';

  final SharedPreferences _preferences;

  bool get hasStoredLocale {
    final value = _preferences.getString(selectedLocaleKey);
    return value != null && value.trim().isNotEmpty;
  }

  Locale loadLocale() {
    final value = _preferences.getString(selectedLocaleKey);
    if (value == null || !AppLocalizations.isSupportedLanguageCode(value)) {
      return const Locale('en');
    }
    return Locale(value);
  }

  Future<void> saveLocale(Locale locale) async {
    final languageCode = AppLocalizations.isSupportedLanguageCode(
      locale.languageCode,
    )
        ? locale.languageCode
        : 'en';
    await _preferences.setString(selectedLocaleKey, languageCode);
  }
}
