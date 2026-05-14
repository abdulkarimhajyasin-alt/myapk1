import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n/app_localizations.dart';
import 'screens/home_screen.dart';
import 'screens/language_selection_screen.dart';
import 'services/expense_network_repository.dart';
import 'services/locale_preference_service.dart';
import 'services/shared_preferences_expense_network_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repository = SharedPreferencesExpenseNetworkRepository();
  await repository.init();
  final preferences = await SharedPreferences.getInstance();
  final localeService = LocalePreferenceService(preferences);
  runApp(
    ExpenseNetworkApp(
      repository: repository,
      localeService: localeService,
    ),
  );
}

class ExpenseNetworkApp extends StatefulWidget {
  const ExpenseNetworkApp({
    required this.repository,
    required this.localeService,
    super.key,
  });

  final ExpenseNetworkRepository repository;
  final LocalePreferenceService localeService;

  @override
  State<ExpenseNetworkApp> createState() => _ExpenseNetworkAppState();
}

class _ExpenseNetworkAppState extends State<ExpenseNetworkApp> {
  late Locale _locale = widget.localeService.loadLocale();
  late bool _hasCompletedLanguageSelection =
      widget.localeService.hasStoredLocale;

  Future<void> _setLocale(Locale locale) async {
    await widget.localeService.saveLocale(locale);
    if (!mounted) return;
    setState(() {
      _locale = locale;
      _hasCompletedLanguageSelection = true;
    });
  }

  Future<void> _changeLocale(Locale locale) async {
    await _setLocale(locale);
  }

  void _openLanguageSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LanguageSelectionScreen(
          selectedLocale: _locale,
          onLocaleSelected: _changeLocale,
          showAppBar: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shared Housing Expenses',
      onGenerateTitle: (context) => context.l10n.appTitle,
      debugShowCheckedModeBanner: false,
      locale: _locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
      home: _hasCompletedLanguageSelection
          ? HomeScreen(
              repository: widget.repository,
              onChangeLanguage: _openLanguageSettings,
            )
          : LanguageSelectionScreen(
              selectedLocale: _locale,
              onLocaleSelected: _setLocale,
            ),
    );
  }
}
