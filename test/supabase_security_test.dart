import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Flutter source does not reference a Supabase service-role key', () {
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    final source = files.map((file) => file.readAsStringSync()).join('\n');

    expect(source.toLowerCase(), isNot(contains('service_role')));
    expect(source.toLowerCase(), isNot(contains('service-role')));
    expect(source.toLowerCase(), isNot(contains('supabase_service')));
  });

  test('Supabase anon key remains configuration-only', () {
    final configSource =
        File('lib/services/supabase_config.dart').readAsStringSync();
    final mainSource = File('lib/main.dart').readAsStringSync();

    expect(
      configSource,
      contains("const String.fromEnvironment('SUPABASE_ANON_KEY')"),
    );
    expect(mainSource, contains('anonKey: supabaseConfig.anonKey'));
    expect(mainSource, isNot(contains('public-anon-key')));
  });

  test('GitHub workflow references secrets without hardcoding values', () {
    final workflow =
        File('.github/workflows/build-android-apk.yml').readAsStringSync();

    expect(workflow, contains('secrets.SUPABASE_URL'));
    expect(workflow, contains('secrets.SUPABASE_ANON_KEY'));
    expect(workflow, contains('SUPABASE_URL configured: yes'));
    expect(workflow, contains('SUPABASE_ANON_KEY configured: yes'));
    expect(workflow, isNot(contains('https://')));
    expect(workflow.toLowerCase(), isNot(contains('service_role')));
    expect(workflow.toLowerCase(), isNot(contains('service-role')));
  });

  test('Phase 1 migration establishes durable Auth membership', () {
    final migration = File(
      'supabase/migrations/20260807000100_harden_auth_membership_rls.sql',
    ).readAsStringSync();

    expect(migration, contains('auth_user_id uuid'));
    expect(migration, contains('references auth.users(id)'));
    expect(migration, contains('network_members_auth_user_id_uidx'));
    expect(migration, contains('where members.auth_user_id = auth.uid()'));
    expect(migration, isNot(contains('auth.jwt()')));
  });

  test('Supabase schema allows only JWT member to edit own active expenses',
      () {
    final schema = File('supabase/schema.sql').readAsStringSync();

    expect(schema, contains('phase5_member_edit_own_active_expenses'));
    expect(schema, contains('for update'));
    expect(schema, contains('archived_at is null'));
    expect(schema, contains('added_by_member_id::text = coalesce('));
    expect(
      schema,
      contains("auth.jwt() -> 'user_metadata' ->> 'maskan_member_id'"),
    );
  });

  test('member create policy does not depend on network row visibility', () {
    final schema = File('supabase/schema.sql').readAsStringSync();

    expect(schema, contains('phase5_network_exists'));
    expect(schema, contains('security definer'));
    expect(schema, contains('public.phase5_network_exists(network_id)'));
  });

  test('repository create avoids select-return dependency during inserts', () {
    final source = File('lib/services/supabase_expense_network_repository.dart')
        .readAsStringSync();
    final createStart = source.indexOf('Future<ExpenseNetwork> createNetwork');
    final createEnd = source.indexOf('@override', createStart + 1);
    final createSource = source.substring(createStart, createEnd);

    expect(createSource, contains('final networkId = createUuid();'));
    expect(createSource, contains('final memberId = createUuid();'));
    expect(createSource, contains('SupabaseAuthIdentity.establish'));
    expect(createSource, contains("action: 'create_network'"));
    expect(createSource, contains('_invokePasswordAction'));
    expect(createSource, contains("duplicateCode: 'duplicate_network'"));
    expect(createSource, isNot(contains("from('networks').insert")));
    expect(createSource, isNot(contains("from('network_members').insert")));
  });

  test('Flutter source does not expose temporary create-network debug text',
      () {
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    final source = files.map((file) => file.readAsStringSync()).join('\n');

    expect(source, isNot(contains('TEMP DEBUG')));
    expect(source, isNot(contains('createNetworkDebugMessage')));
  });

  test('member leave is one server-authorized transaction', () {
    final source = File('lib/services/supabase_expense_network_repository.dart')
        .readAsStringSync();
    final migration = File(
      'supabase/migrations/20260807000100_harden_auth_membership_rls.sql',
    ).readAsStringSync();

    expect(source, contains("'maskan_leave_network'"));
    expect(source, isNot(contains('_deleteNetworkCascade')));
    expect(
      migration,
      contains('create or replace function public.maskan_leave_network'),
    );
    expect(migration, contains('m.auth_user_id = auth.uid()'));
  });

  test('Supabase schema configures member avatar storage bucket', () {
    final schema = File('supabase/schema.sql').readAsStringSync();

    expect(schema, contains('member-avatars'));
    expect(schema, contains('storage.buckets'));
    expect(schema, contains('storage.objects'));
    expect(schema, contains('image/jpeg'));
    expect(schema, contains('image/png'));
    expect(schema, contains('image/webp'));
    expect(schema, contains('storage.foldername(name))[2]'));
    expect(schema, contains('maskan_member_id'));
  });

  test('avatar uploads use per-upload storage objects', () {
    final source = File('lib/services/member_avatar_photo_service.dart')
        .readAsStringSync();
    final sessionSource = File('lib/services/supabase_session_repository.dart')
        .readAsStringSync();

    expect(source, contains('millisecondsSinceEpoch'));
    expect(source, contains('upsert: false'));
    expect(source, contains('_verifyExistingAuth(memberId)'));
    expect(source, isNot(contains('updateUser(')));
    expect(source, isNot(contains('refreshSession()')));
    expect(sessionSource, contains('updateUser('));
    expect(sessionSource, contains('refreshSession()'));
  });

  test('admin password reset uses the narrow Phase 2 server function', () {
    final migration = File(
      'supabase/migrations/20260820000000_migrate_password_security.sql',
    ).readAsStringSync();
    final source = File('lib/services/supabase_expense_network_repository.dart')
        .readAsStringSync();

    expect(migration, contains('maskan_password_reset_context'));
    expect(migration, contains('maskan_password_reset_member'));
    expect(migration, contains('a.auth_user_id = p_caller_auth_user_id'));
    expect(migration, contains('n.created_by_member_id = a.id'));
    expect(migration, contains('legacy_password_hash = null'));
    expect(source, contains("action: 'reset_member_password'"));
    expect(source, isNot(contains('phase5_reset_member_password')));
    expect(source, isNot(contains('service_role')));
  });

  test('expense update requires auth session before Supabase update', () {
    final source = File('lib/services/supabase_expense_network_repository.dart')
        .readAsStringSync();
    final updateStart = source.indexOf('Future<ExpenseNetwork> updateExpense');
    final updateEnd = source.indexOf('@override', updateStart + 1);
    final updateSource = source.substring(updateStart, updateEnd);

    expect(updateSource, contains('_ensureExpenseEditAuthSession'));
    expect(source, contains('supabase_auth_session_required'));
    final expenseUpdate = updateSource.indexOf('.update(');
    expect(expenseUpdate, greaterThanOrEqualTo(0));
    expect(
      updateSource.indexOf('_ensureExpenseEditAuthSession'),
      lessThan(expenseUpdate),
    );
  });

  test('Flutter source does not create anonymous Supabase sessions', () {
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    final source = files.map((file) => file.readAsStringSync()).join('\n');

    expect(source, isNot(contains('signInAnonymously')));
  });

  test('Phase 1 exposes safe views and ships repeatable isolation tests', () {
    final migration = File(
      'supabase/migrations/20260807000100_harden_auth_membership_rls.sql',
    ).readAsStringSync();
    final sqlTest = File(
      'supabase/tests/phase_01_rls_isolation.sql',
    ).readAsStringSync();

    expect(migration, contains('with (security_invoker = true)'));
    expect(migration, contains('null::text as password_hash'));
    expect(migration, contains('null::text as network_password_hash'));
    expect(migration, contains('from anon, authenticated'));
    expect(sqlTest, contains('A1 cross-network insert was accepted'));
    expect(sqlTest, contains('B1 inverse network isolation failed'));
    expect(sqlTest, contains('anon listed private networks'));
    expect(sqlTest, contains('A1 spoofed A2 actor was accepted'));
  });

  test('local migration chain starts from the reviewed pre-Phase-1 schema', () {
    final schema = File('supabase/schema.sql').readAsLinesSync();
    final baseline = File(
      'supabase/migrations/20260807000000_baseline_pre_phase1.sql',
    ).readAsLinesSync();
    final migrations = Directory('supabase/migrations')
        .listSync()
        .whereType<File>()
        .map((file) => file.uri.pathSegments.last)
        .toList()
      ..sort();

    expect(baseline.skip(4), orderedEquals(schema));
    expect(
      migrations,
      orderedEquals([
        '20260807000000_baseline_pre_phase1.sql',
        '20260807000100_harden_auth_membership_rls.sql',
        '20260820000000_migrate_password_security.sql',
      ]),
    );
    expect(baseline.join('\n'), isNot(contains('auth_user_id uuid')));
  });
}
