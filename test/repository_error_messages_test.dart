import 'package:expense_network/l10n/app_localizations.dart';
import 'package:expense_network/services/repository_error_messages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const l10n = AppLocalizations(Locale('en'));

  test('maps Supabase network failures to a user-friendly message', () {
    expect(
      RepositoryErrorMessages.fromCode(
        l10n,
        'supabase_network_unavailable',
      ),
      contains('internet connection'),
    );
  });

  test('maps common credential and duplicate errors', () {
    expect(
      RepositoryErrorMessages.fromCode(l10n, 'duplicate_network'),
      'This network name is already in use. Choose another name.',
    );
    expect(
      RepositoryErrorMessages.fromCode(l10n, 'duplicate_member'),
      'This member name is already used in the network.',
    );
    expect(
      RepositoryErrorMessages.fromCode(l10n, 'network_invalid_credentials'),
      'Network name or password is incorrect.',
    );
    expect(
      RepositoryErrorMessages.fromCode(l10n, 'member_invalid_password'),
      'Personal password is incorrect.',
    );
  });

  test('maps Supabase permission errors', () {
    expect(
      RepositoryErrorMessages.fromCode(l10n, 'supabase_permission_denied'),
      contains('RLS'),
    );
  });

  test('maps stale cloud records to user-friendly recovery copy', () {
    expect(
      RepositoryErrorMessages.fromCode(l10n, 'supabase_not_found'),
      'This saved network is no longer available. Please create or join a network again.',
    );
    expect(
      RepositoryErrorMessages.fromCode(l10n, 'network_not_found'),
      contains('create or join'),
    );
    expect(
      RepositoryErrorMessages.fromCode(l10n, 'member_not_found'),
      contains('create or join'),
    );
  });

  test('maps create network failures without stale-session copy', () {
    expect(
      RepositoryErrorMessages.fromCode(l10n, 'supabase_create_network_failed'),
      'Could not create the network. Please try again.',
    );
  });

  test('maps avatar photo errors to friendly messages', () {
    expect(
      RepositoryErrorMessages.fromCode(
        l10n,
        'avatar_photo_permission_denied',
      ),
      contains('Photo access was denied'),
    );
    expect(
      RepositoryErrorMessages.fromCode(l10n, 'avatar_photo_upload_failed'),
      contains('Could not update your profile photo'),
    );
  });
}
