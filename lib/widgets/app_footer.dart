import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

class AppFooter extends StatelessWidget {
  const AppFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
      child: Text(
        context.l10n.footerText,
        textAlign: TextAlign.center,
        textDirection: TextDirection.rtl,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
