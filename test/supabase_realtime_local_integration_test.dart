import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../supabase/tests/phase_01_realtime_isolation.dart' as realtime;

void main() {
  final hasLocalConfiguration =
      Platform.environment['LOCAL_SUPABASE_API_URL'] != null &&
          Platform.environment['LOCAL_SUPABASE_ANON_KEY'] != null;

  test(
    'local Realtime subscriptions remain isolated by network',
    realtime.main,
    skip: hasLocalConfiguration
        ? false
        : 'Local Supabase environment variables are not configured.',
  );
}
