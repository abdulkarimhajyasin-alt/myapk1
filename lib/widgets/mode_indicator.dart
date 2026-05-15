import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/supabase_config.dart';

class ModeIndicator extends StatelessWidget {
  const ModeIndicator({
    this.config = SupabaseConfig.defaultConfig,
    super.key,
  });

  final SupabaseConfig config;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCloudMode = config.shouldUseSupabase;
    final color = isCloudMode
        ? theme.colorScheme.tertiary
        : theme.colorScheme.onSurfaceVariant;

    return Align(
      alignment: AlignmentDirectional.center,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: color.withAlpha(89)),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isCloudMode
                    ? Icons.cloud_done_rounded
                    : Icons.phone_android_rounded,
                size: 14,
                color: color,
              ),
              const SizedBox(width: 6),
              Text(
                isCloudMode ? context.l10n.cloudTestMode : context.l10n.localMode,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
