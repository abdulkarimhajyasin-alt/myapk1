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

  test('Supabase schema includes member leave delete policy', () {
    final schema = File('supabase/schema.sql').readAsStringSync();

    expect(schema, contains('phase5_interim_leave_network'));
    expect(schema, contains('on public.network_members'));
    expect(schema, contains('for delete'));
    expect(schema, contains('phase5_network_has_no_active_expenses'));
    expect(schema, contains('sum(amount_cents)'));
    expect(schema, contains('phase5_interim_delete_empty_networks'));
    expect(schema, contains('phase5_interim_delete_settled_network_expenses'));
    expect(schema, contains('on delete set null'));
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
    expect(createSource, contains("'id': networkId"));
    expect(createSource, contains("'id': memberId"));
    expect(createSource, contains('insertedNetwork = true'));
    expect(
      createSource,
      contains('insertedNetwork && !isDuplicateSupabaseError(error)'),
    );
    expect(createSource, contains('_tryDeletePartialNetwork('));
    expect(createSource, contains("duplicateCode: 'duplicate_network'"));
    expect(createSource, isNot(contains('.select()\n          .single()')));
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

  test('final network cleanup deletes all network-owned Supabase rows', () {
    final source = File('lib/services/supabase_expense_network_repository.dart')
        .readAsStringSync();
    final cleanupStart = source.indexOf('Future<void> _deleteNetworkCascade');
    final cleanupEnd = source.indexOf('@override', cleanupStart + 1);
    final cleanupSource = source.substring(cleanupStart, cleanupEnd);

    expect(cleanupSource, contains("from('network_notifications')"));
    expect(cleanupSource, contains("from('expense_reset_approvals')"));
    expect(cleanupSource, contains("from('expense_reset_requests')"));
    expect(cleanupSource, contains("from('expenses')"));
    expect(cleanupSource, contains("from('expense_cycles')"));
    expect(cleanupSource, contains("from('network_members')"));
    expect(cleanupSource, contains("from('networks')"));
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

  test('admin member password reset uses a narrow Supabase RPC', () {
    final schema = File('supabase/schema.sql').readAsStringSync();
    final source = File('lib/services/supabase_expense_network_repository.dart')
        .readAsStringSync();

    expect(schema, contains('phase5_reset_member_password'));
    expect(schema, contains('security definer'));
    expect(schema, contains('created_by_member_id = admin_member_id'));
    expect(schema, contains('admin_member_id::text <> jwt_member_id'));
    expect(source, contains('phase5_reset_member_password'));
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
    expect(
      updateSource.indexOf('_ensureExpenseEditAuthSession'),
      lessThan(updateSource.indexOf(".from('expenses')\n          .update(")),
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
}
