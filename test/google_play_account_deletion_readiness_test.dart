import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    'supabase/migrations/20260826000000_add_account_deletion.sql',
  ).readAsStringSync();
  final edgeFunction = File(
    'supabase/functions/maskan-delete-account/index.ts',
  ).readAsStringSync();
  final flutterService = File(
    'lib/services/account_deletion_service.dart',
  ).readAsStringSync();
  final supabaseConfig = File('supabase/config.toml').readAsStringSync();

  test('Android release configuration explicitly targets API 36', () {
    final gradle = File('android/app/build.gradle').readAsStringSync();
    final gradleProperties =
        File('android/gradle.properties').readAsStringSync();

    expect(gradle, contains('compileSdk = 36'));
    expect(gradle, contains('targetSdk = 36'));
    expect(gradle, contains('minSdkVersion = flutter.minSdkVersion'));
    expect(gradle, contains('applicationId = "com.expensenetwork.app"'));
    expect(gradleProperties, contains('-Duser.language=en'));
    expect(gradleProperties, contains('-Duser.country=US'));
    expect(gradleProperties, contains('-Dfile.encoding=UTF-8'));
  });

  test('Android permissions keep only justified runtime capabilities', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    final avatarService = File('lib/services/member_avatar_photo_service.dart')
        .readAsStringSync();

    expect(manifest, contains('android.permission.INTERNET'));
    expect(manifest, contains('android.permission.POST_NOTIFICATIONS'));
    expect(manifest, contains('android.permission.CAMERA'));
    expect(manifest, isNot(contains('READ_MEDIA_IMAGES')));
    expect(manifest, isNot(contains('READ_MEDIA_VIDEO')));
    expect(manifest, isNot(contains('READ_EXTERNAL_STORAGE')));
    expect(manifest, isNot(contains('MANAGE_EXTERNAL_STORAGE')));
    expect(avatarService, contains('source: ImageSource.gallery'));
  });

  test('database deletion authority is auth uid plus one-use reauth token', () {
    expect(
      migration,
      contains('create or replace function public.maskan_delete_account_data'),
    );
    expect(migration, contains('v_auth_user_id uuid := auth.uid()'));
    expect(migration, contains('p_deletion_token text'));
    expect(migration, isNot(contains('p_member_id uuid')));
    expect(migration, contains('account_deletion_authorizations'));
    expect(migration,
        contains('deletion_authorization.token_hash = v_token_hash'));
    expect(
      migration,
      contains(
        'grant execute on function public.maskan_delete_account_data(text, boolean)',
      ),
    );
  });

  test('owner and shared-history behavior is explicit and data preserving', () {
    expect(migration, contains('owner_transfer_required'));
    expect(migration, contains('network_confirmation_required'));
    expect(migration, contains('if v_member_count = 1 then'));
    expect(migration, contains("paid_by_member_name = 'Deleted account'"));
    expect(migration, contains("added_by_member_name = 'Deleted account'"));
    expect(migration, contains('required_member_ids = array_remove'));
    expect(migration, contains('delete from public.network_members'));
    expect(migration, contains('account_deletion_required'));
  });

  test('trusted edge path reauthenticates and removes storage and Auth user',
      () {
    expect(edgeFunction, contains('/auth/v1/user'));
    expect(edgeFunction, contains('grant_type=password'));
    expect(edgeFunction, contains('maskan_authorize_account_deletion'));
    expect(edgeFunction, contains('maskan_delete_account_data'));
    expect(edgeFunction, contains('/storage/v1/object/list/'));
    expect(edgeFunction, contains('/auth/v1/admin/users/'));
    expect(edgeFunction, contains('SUPABASE_SERVICE_ROLE_KEY'));
    expect(supabaseConfig, contains('[functions.maskan-delete-account]'));
    expect(supabaseConfig, contains('verify_jwt = false'));
    expect(edgeFunction, isNot(contains('console.log')));
    expect(edgeFunction, isNot(contains('console.error(body')));
  });

  test('Flutter client has no service role and clears the deleted session', () {
    expect(flutterService.toLowerCase(), isNot(contains('service_role')));
    expect(flutterService, contains("'maskan-delete-account'"));
    expect(flutterService, contains('SignOutScope.local'));
    expect(flutterService, isNot(contains('memberId')));
    expect(flutterService, isNot(contains('networkId')));
  });
}
