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
    return fromCode(l10n, error.code) ??
        _safeFallbackMessage(l10n, error.message);
  }

  static String? fromCode(AppLocalizations l10n, String? code) {
    return switch (code) {
      'supabase_network_unavailable' => l10n.errorNoInternet,
      'duplicate_network' => l10n.errorDuplicateNetwork,
      'duplicate_member' => l10n.errorDuplicateMember,
      'network_invalid_credentials' => l10n.errorWrongNetworkPassword,
      'member_invalid_password' => l10n.errorWrongPersonalPassword,
      'supabase_permission_denied' => l10n.errorSupabasePermission,
      'supabase_not_found' => l10n.errorCloudRecordUnavailable,
      'network_not_found' => l10n.errorCloudRecordUnavailable,
      'member_not_found' => l10n.errorCloudRecordUnavailable,
      'supabase_create_network_failed' => l10n.errorCreateNetworkFailed,
      'avatar_photo_permission_denied' => l10n.avatarPhotoPermissionDenied,
      'avatar_photo_missing' => l10n.avatarPhotoMissing,
      'avatar_photo_pick_failed' => l10n.avatarPhotoPickFailed,
      'avatar_photo_too_large' => l10n.avatarPhotoTooLarge,
      'avatar_photo_upload_failed' => l10n.avatarPhotoUploadFailed,
      'avatar_photo_auth_required' => l10n.avatarPhotoAuthRequired,
      'avatar_photo_storage_not_configured' =>
        l10n.avatarPhotoStorageNotConfigured,
      'avatar_photo_storage_permission_denied' =>
        l10n.avatarPhotoStoragePermissionDenied,
      'supabase_member_profile_update_failed' =>
        l10n.avatarPhotoProfileUpdateFailed,
      'supabase_member_profile_update_auth_required' =>
        l10n.avatarPhotoAuthRequired,
      'supabase_not_initialized' => l10n.errorSupabaseNotConfigured,
      'reset_request_already_pending' => l10n.resetRequestAlreadyPending,
      'reset_request_not_pending' => l10n.resetApprovalFailed,
      'reset_approval_not_required' => l10n.resetApprovalFailed,
      'supabase_reset_approval_failed' => l10n.resetApprovalFailed,
      'supabase_reset_request_create_failed' => l10n.cycleCompletionFailed,
      _ => null,
    };
  }

  static String _safeFallbackMessage(AppLocalizations l10n, String message) {
    final normalized = message.toLowerCase();
    final looksLikeBackendDebug = normalized.contains('temp debug') ||
        normalized.contains('current_stage:') ||
        normalized.contains('backend_code:') ||
        normalized.contains('backend_message:') ||
        normalized.contains('normalized_name:');
    if (looksLikeBackendDebug) return l10n.errorCreateNetworkFailed;
    return message;
  }
}
