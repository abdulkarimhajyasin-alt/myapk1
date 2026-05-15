import 'package:flutter/widgets.dart';

import '../l10n/app_localizations.dart';
import 'expense_network_repository.dart';

class RepositoryErrorMessages {
  const RepositoryErrorMessages._();

  static String fromException(
    BuildContext context,
    RepositoryException error,
  ) {
    final l10n = context.l10n;
    return fromCode(l10n, error.code) ?? error.message;
  }

  static String? fromCode(AppLocalizations l10n, String? code) {
    return switch (code) {
      'supabase_network_unavailable' => l10n.errorNoInternet,
      'duplicate_network' => l10n.errorDuplicateNetwork,
      'duplicate_member' => l10n.errorDuplicateMember,
      'network_invalid_credentials' => l10n.errorWrongNetworkPassword,
      'member_invalid_password' => l10n.errorWrongPersonalPassword,
      'supabase_permission_denied' => l10n.errorSupabasePermission,
      'supabase_not_initialized' => l10n.errorSupabaseNotConfigured,
      _ => null,
    };
  }
}
