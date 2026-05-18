import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

class ModeIndicator extends StatelessWidget {
  const ModeIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.tertiary;

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
                Icons.cloud_done_rounded,
                size: 14,
                color: color,
              ),
              const SizedBox(width: 6),
              Text(
                context.l10n.cloudConnected,
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
