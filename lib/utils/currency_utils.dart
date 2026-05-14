import 'package:flutter/material.dart';

class NetworkCurrency {
  const NetworkCurrency({
    required this.code,
    required this.symbol,
    required this.englishName,
    required this.arabicName,
  });

  final String code;
  final String symbol;
  final String englishName;
  final String arabicName;

  String labelFor(Locale locale) {
    final name = locale.languageCode == 'ar' ? arabicName : englishName;
    return '$code — $symbol — $name';
  }
}

class CurrencyCatalog {
  const CurrencyCatalog._();

  static const defaultCurrency = NetworkCurrency(
    code: 'USD',
    symbol: r'$',
    englishName: 'US Dollar',
    arabicName: 'الدولار الأمريكي',
  );

  static const supportedCurrencies = [
    defaultCurrency,
    NetworkCurrency(
      code: 'EUR',
      symbol: '€',
      englishName: 'Euro',
      arabicName: 'اليورو',
    ),
    NetworkCurrency(
      code: 'GBP',
      symbol: '£',
      englishName: 'British Pound',
      arabicName: 'الجنيه الإسترليني',
    ),
    NetworkCurrency(
      code: 'TRY',
      symbol: '₺',
      englishName: 'Turkish Lira',
      arabicName: 'الليرة التركية',
    ),
    NetworkCurrency(
      code: 'SAR',
      symbol: 'ر.س',
      englishName: 'Saudi Riyal',
      arabicName: 'الريال السعودي',
    ),
    NetworkCurrency(
      code: 'AED',
      symbol: 'د.إ',
      englishName: 'UAE Dirham',
      arabicName: 'الدرهم الإماراتي',
    ),
    NetworkCurrency(
      code: 'SYP',
      symbol: '£S',
      englishName: 'Syrian Pound',
      arabicName: 'الليرة السورية',
    ),
    NetworkCurrency(
      code: 'IQD',
      symbol: 'د.ع',
      englishName: 'Iraqi Dinar',
      arabicName: 'الدينار العراقي',
    ),
    NetworkCurrency(
      code: 'JOD',
      symbol: 'د.أ',
      englishName: 'Jordanian Dinar',
      arabicName: 'الدينار الأردني',
    ),
  ];

  static NetworkCurrency findByCode(String? code) {
    if (code == null) return defaultCurrency;
    final normalizedCode = code.trim().toUpperCase();
    for (final currency in supportedCurrencies) {
      if (currency.code == normalizedCode) return currency;
    }
    return defaultCurrency;
  }

  static bool isSupportedCode(String? code) {
    if (code == null) return false;
    final normalizedCode = code.trim().toUpperCase();
    return supportedCurrencies.any((currency) => currency.code == normalizedCode);
  }
}
