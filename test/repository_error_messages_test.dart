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
      'A network with this name already exists.',
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
}
