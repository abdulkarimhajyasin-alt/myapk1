import 'dart:io';

import 'package:expense_network/services/supabase_auth_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('technical Supabase Auth password is bounded and deterministic', () {
    final first = SupabaseAuthIdentity.passwordFor(
      '11111111-1111-1111-1111-111111111111',
      'member password',
    );
    final repeated = SupabaseAuthIdentity.passwordFor(
      '11111111-1111-1111-1111-111111111111',
      'member password',
    );
    final otherMember = SupabaseAuthIdentity.passwordFor(
      '22222222-2222-2222-2222-222222222222',
      'member password',
    );

    expect(first, repeated);
    expect(first, matches(RegExp(r'^[0-9a-f]{64}$')));
    expect(first.length, lessThanOrEqualTo(72));
    expect(first, isNot(otherMember));
  });

  test('Flutter delegates every cloud password authority to Edge', () {
    final repository = File(
      'lib/services/supabase_expense_network_repository.dart',
    ).readAsStringSync();

    expect(repository, contains("'maskan-password'"));
    expect(repository, contains("action: 'create_network'"));
    expect(repository, contains("action: 'join_network'"));
    expect(repository, contains("action: 'verify_member'"));
    expect(repository, contains("action: 'reset_member_password'"));
    expect(repository, isNot(contains('PasswordHashUtils')));
    expect(repository, isNot(contains('p_member_password_hash')));
    expect(repository, isNot(contains('p_network_password_hash')));
    expect(repository, isNot(contains('service_role')));
  });

  test('Phase 2 migration stores versioned modern credentials privately', () {
    final migration = File(
      'supabase/migrations/20260820000000_migrate_password_security.sql',
    ).readAsStringSync();

    expect(migration, contains('pbkdf2-hmac-sha256-v1'));
    expect(migration, contains(r'$maskan$pbkdf2-sha256$v=1$i=600000$l=32$'));
    expect(migration, contains('legacy_password_hash = null'));
    expect(migration, contains('legacy_password_salt = null'));
    expect(migration, contains('maskan_reject_credential_downgrade'));
    expect(migration, contains('auth_password_version'));
    expect(
      migration,
      contains(
        'grant execute on function public.maskan_password_lookup_member(text, text, uuid) to service_role',
      ),
    );
    expect(
      migration,
      contains(
        'revoke all on function public.maskan_password_lookup_member(text, text, uuid) from public, anon, authenticated',
      ),
    );
  });

  test('Edge KDF uses Web Crypto PBKDF2 and isolates FNV to migration', () {
    final core = File(
      'supabase/functions/_shared/password_security.ts',
    ).readAsStringSync();
    final edge = File(
      'supabase/functions/maskan-password/index.ts',
    ).readAsStringSync();

    expect(core, contains('PBKDF2_ITERATIONS = 600_000'));
    expect(core, contains('crypto.subtle.deriveBits'));
    expect(core, contains('crypto.getRandomValues'));
    expect(core, contains('verifyLegacyPassword'));
    expect(core, contains('It must never be used to create a new credential'));
    expect(edge, contains('maskan_password_upgrade_member'));
    expect(edge, contains('maskan_password_upgrade_network'));
    expect(edge, contains('maskan_password_mark_auth_synced'));
    expect(edge, isNot(contains('console.log')));
    expect(edge, isNot(contains('console.error(body')));
  });

  test('repeatable local integration matrix covers critical scenarios', () {
    final script = File(
      'supabase/tests/phase_02_password_security.ps1',
    ).readAsStringSync();

    expect(script, contains('new network is modern only'));
    expect(script, contains('wrong legacy member password does not migrate'));
    expect(
        script, contains('old password rejected after reset by app and Auth'));
    expect(
        script, contains('cross-network reset and member-ID spoofing denied'));
    expect(script, contains('public API projections expose no hash or salt'));
    expect(script,
        contains('concurrent migration leaves one valid modern credential'));
  });
}
