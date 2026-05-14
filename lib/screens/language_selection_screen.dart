import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({
    required this.selectedLocale,
    required this.onLocaleSelected,
    this.showAppBar = false,
    super.key,
  });

  final Locale selectedLocale;
  final Future<void> Function(Locale locale) onLocaleSelected;
  final bool showAppBar;

  @override
  State<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  late Locale _selectedLocale = widget.selectedLocale;

  void _selectLocale(Locale locale) {
    setState(() => _selectedLocale = locale);
  }

  Future<void> _continue() async {
    await widget.onLocaleSelected(_selectedLocale);
    if (!mounted || !widget.showAppBar) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final content = SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.language_rounded,
                  size: 70,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 22),
                Text(
                  l10n.chooseLanguage,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  l10n.chooseLanguageSubtitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 30),
                _LanguageOption(
                  title: l10n.english,
                  locale: const Locale('en'),
                  selectedLocale: _selectedLocale,
                  onSelected: _selectLocale,
                ),
                const SizedBox(height: 12),
                _LanguageOption(
                  title: l10n.arabic,
                  locale: const Locale('ar'),
                  selectedLocale: _selectedLocale,
                  onSelected: _selectLocale,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _continue,
                  child: Text(l10n.continueAction),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: Text(l10n.language),
            )
          : null,
      body: content,
    );
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.title,
    required this.locale,
    required this.selectedLocale,
    required this.onSelected,
  });

  final String title;
  final Locale locale;
  final Locale selectedLocale;
  final ValueChanged<Locale> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSelected = locale.languageCode == selectedLocale.languageCode;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onSelected(locale),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                isSelected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
