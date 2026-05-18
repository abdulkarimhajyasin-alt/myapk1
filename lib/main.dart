import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'l10n/app_localizations.dart';
import 'screens/home_screen.dart';
import 'screens/join_network_screen.dart';
import 'screens/language_selection_screen.dart';
import 'services/expense_network_repository.dart';
import 'services/invite_service.dart';
import 'services/locale_preference_service.dart';
import 'services/repository_factory.dart';
import 'services/session_repository.dart';
import 'services/supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const supabaseConfig = SupabaseConfig.defaultConfig;
  if (supabaseConfig.shouldUseSupabase) {
    await Supabase.initialize(
      url: supabaseConfig.url,
      anonKey: supabaseConfig.anonKey,
    );
  }

  final preferences = await SharedPreferences.getInstance();
  final repositories = await RepositoryFactory.create(
    preferences: preferences,
    supabaseConfig: supabaseConfig,
  );
  final localeService = LocalePreferenceService(preferences);
  runApp(
    ExpenseNetworkApp(
      repository: repositories.expenseNetworkRepository,
      sessionRepository: repositories.sessionRepository,
      localeService: localeService,
      dataMode: supabaseConfig.shouldUseSupabase ? 'supabase' : 'local',
    ),
  );
}

class ExpenseNetworkApp extends StatefulWidget {
  const ExpenseNetworkApp({
    required this.repository,
    required this.sessionRepository,
    required this.localeService,
    required this.dataMode,
    super.key,
  });

  final ExpenseNetworkRepository repository;
  final SessionRepository sessionRepository;
  final LocalePreferenceService localeService;
  final String dataMode;

  @override
  State<ExpenseNetworkApp> createState() => _ExpenseNetworkAppState();
}

class _ExpenseNetworkAppState extends State<ExpenseNetworkApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final InviteService _inviteService = const InviteService();
  StreamSubscription<Uri>? _linkSubscription;
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

  @override
  void initState() {
    super.initState();
    _listenForInviteLinks();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  Future<void> _listenForInviteLinks() async {
    final appLinks = AppLinks();
    try {
      final initialLink = await appLinks.getInitialLink();
      if (!mounted) return;
      if (initialLink != null) _openInviteLink(initialLink);
    } catch (_) {
      // Deep link delivery should never block normal app startup.
    }
    _linkSubscription = appLinks.uriLinkStream.listen(_openInviteLink);
  }

  void _openInviteLink(Uri uri) {
    final networkId = _inviteService.parseNetworkId(uri.toString());
    if (networkId == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigator = _navigatorKey.currentState;
      if (navigator == null) return;
      navigator.push(
        MaterialPageRoute(
          builder: (_) => JoinNetworkScreen(
            repository: widget.repository,
            sessionRepository: widget.sessionRepository,
            dataMode: widget.dataMode,
            inviteNetworkId: networkId,
          ),
        ),
      );
    });
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
      navigatorKey: _navigatorKey,
      title: 'Maskan',
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
              sessionRepository: widget.sessionRepository,
              dataMode: widget.dataMode,
              onChangeLanguage: _openLanguageSettings,
            )
          : LanguageSelectionScreen(
              selectedLocale: _locale,
              onLocaleSelected: _setLocale,
            ),
    );
  }
}
