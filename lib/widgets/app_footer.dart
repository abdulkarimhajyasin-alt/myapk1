import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';

class AppFooter extends StatelessWidget {
  const AppFooter({super.key});

  static final Uri _karamixLabsUri = Uri.parse('https://karamixlabs.com');

  Future<void> _openKaramixLabs(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final errorMessage = context.l10n.karamixLabsLaunchError;

    try {
      final launched = await launchUrl(
        _karamixLabsUri,
        mode: LaunchMode.externalApplication,
      );
      if (launched || !context.mounted) return;
    } catch (_) {
      if (!context.mounted) return;
    }

    messenger.showSnackBar(
      SnackBar(content: Text(errorMessage)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            label: l10n.karamixLabsButtonTooltip,
            button: true,
            child: Tooltip(
              message: l10n.karamixLabsButtonTooltip,
              child: OutlinedButton.icon(
                onPressed: () => _openKaramixLabs(context),
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: Text(l10n.karamixLabsButtonLabel),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  visualDensity: VisualDensity.compact,
                  foregroundColor: theme.colorScheme.primary,
                  side: BorderSide(
                    color: theme.colorScheme.primary.withAlpha(82),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.footerText,
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
