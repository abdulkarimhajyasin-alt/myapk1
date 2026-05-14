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
}
