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
    expect(schema, contains('phase5_interim_delete_empty_networks'));
    expect(schema, contains('phase5_interim_delete_settled_network_expenses'));
    expect(schema, contains('on delete set null'));
  });
}
