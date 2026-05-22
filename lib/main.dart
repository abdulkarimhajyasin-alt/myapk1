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
  final preferences = await SharedPreferences.getInstance();
  final localeService = LocalePreferenceService(preferences);
  runApp(
    ExpenseNetworkBootstrap(
      localeService: localeService,
      preferences: preferences,
    ),
  );
}

class ExpenseNetworkBootstrap extends StatefulWidget {
  const ExpenseNetworkBootstrap({
    required this.localeService,
    required this.preferences,
    super.key,
  });

  final LocalePreferenceService localeService;
  final SharedPreferences preferences;

  @override
  State<ExpenseNetworkBootstrap> createState() =>
      _ExpenseNetworkBootstrapState();
}

class _ExpenseNetworkBootstrapState extends State<ExpenseNetworkBootstrap> {
  static const supabaseConfig = SupabaseConfig.defaultConfig;
  Future<AppRepositoryBundle>? _bootstrapFuture;
  bool _hasInitializedSupabase = false;

  @override
  void initState() {
    super.initState();
    _bootstrapFuture = _initializeCloud();
  }

  Future<AppRepositoryBundle> _initializeCloud() async {
    supabaseConfig.requireConfigured();
    await _ensureSupabaseInitialized();
    return RepositoryFactory.create(preferences: widget.preferences);
  }

  Future<void> _ensureSupabaseInitialized() async {
    if (_hasInitializedSupabase) return;
    await Supabase.initialize(
      url: supabaseConfig.url,
      anonKey: supabaseConfig.anonKey,
    );
    _hasInitializedSupabase = true;
  }

  void _retry() {
    setState(() => _bootstrapFuture = _initializeCloud());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppRepositoryBundle>(
      future: _bootstrapFuture,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final repositories = snapshot.data!;
          return ExpenseNetworkApp(
            repository: repositories.expenseNetworkRepository,
            sessionRepository: repositories.sessionRepository,
            localeService: widget.localeService,
          );
        }
        if (snapshot.hasError) {
          return CloudInitializationFailureApp(
            localeService: widget.localeService,
            error: snapshot.error,
            onRetry: _retry,
          );
        }
        return CloudInitializationLoadingApp(
          localeService: widget.localeService,
        );
      },
    );
  }
}

class ExpenseNetworkApp extends StatefulWidget {
  const ExpenseNetworkApp({
    required this.repository,
    required this.sessionRepository,
    required this.localeService,
    super.key,
  });

  final ExpenseNetworkRepository repository;
  final SessionRepository sessionRepository;
  final LocalePreferenceService localeService;

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
      theme: _appTheme(),
      home: _hasCompletedLanguageSelection
          ? HomeScreen(
              repository: widget.repository,
              sessionRepository: widget.sessionRepository,
              onChangeLanguage: _openLanguageSettings,
            )
          : LanguageSelectionScreen(
              selectedLocale: _locale,
              onLocaleSelected: _setLocale,
            ),
    );
  }
}

class CloudInitializationLoadingApp extends StatelessWidget {
  const CloudInitializationLoadingApp({
    required this.localeService,
    super.key,
  });

  final LocalePreferenceService localeService;

  @override
  Widget build(BuildContext context) {
    return _BootstrapMaterialApp(
      locale: localeService.loadLocale(),
      home: const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class CloudInitializationFailureApp extends StatelessWidget {
  const CloudInitializationFailureApp({
    required this.localeService,
    required this.error,
    required this.onRetry,
    super.key,
  });

  final LocalePreferenceService localeService;
  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _BootstrapMaterialApp(
      locale: localeService.loadLocale(),
      home: _CloudInitializationFailureScreen(
        error: error,
        onRetry: onRetry,
      ),
    );
  }
}

class _BootstrapMaterialApp extends StatelessWidget {
  const _BootstrapMaterialApp({
    required this.locale,
    required this.home,
  });

  final Locale locale;
  final Widget home;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Maskan',
      debugShowCheckedModeBanner: false,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: _appTheme(),
      home: home,
    );
  }
}

class _CloudInitializationFailureScreen extends StatelessWidget {
  const _CloudInitializationFailureScreen({
    required this.error,
    required this.onRetry,
  });

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final isConfigurationError = error is SupabaseConfigurationException;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.cloud_off_rounded,
                    size: 64,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    isConfigurationError
                        ? l10n.errorSupabaseNotConfigured
                        : l10n.cloudConnectionFailedTitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    isConfigurationError
                        ? l10n.supabaseConfigurationMissingMessage
                        : l10n.cloudConnectionFailedMessage,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(l10n.retry),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

ThemeData _appTheme() {
  return ThemeData(
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
  );
}
