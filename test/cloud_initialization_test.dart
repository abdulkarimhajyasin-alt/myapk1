import 'package:expense_network/l10n/app_localizations.dart';
import 'package:expense_network/main.dart';
import 'package:expense_network/services/locale_preference_service.dart';
import 'package:expense_network/services/supabase_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('missing Supabase configuration has a distinct startup message',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      LocalePreferenceService.selectedLocaleKey: 'en',
    });
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      CloudInitializationFailureApp(
        localeService: LocalePreferenceService(preferences),
        error: const SupabaseConfigurationException('missing'),
        onRetry: () {},
      ),
    );

    expect(find.text('Supabase configuration missing'), findsOneWidget);
    expect(find.text('Cloud connection unavailable'), findsNothing);
  });

  testWidgets('network startup failures keep the cloud unavailable message',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      LocalePreferenceService.selectedLocaleKey: 'en',
    });
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      CloudInitializationFailureApp(
        localeService: LocalePreferenceService(preferences),
        error: Exception('SocketException'),
        onRetry: () {},
      ),
    );

    expect(find.text('Cloud connection unavailable'), findsOneWidget);
    expect(find.text('Supabase configuration missing'), findsNothing);
  });

  test('localizations expose cloud startup copy', () {
    const l10n = AppLocalizations(Locale('en'));
    const arabic = AppLocalizations(Locale('ar'));

    expect(l10n.errorSupabaseNotConfigured, 'Supabase configuration missing');
    expect(l10n.supabaseConfigurationMissingMessage, isNotEmpty);
    expect(
      arabic.confirmLeaveNetwork,
      'هل تريد حذف حسابك ومغادرة شبكة المصروف نهائيًا؟',
    );
    expect(
      arabic.lastMemberLeaveWarning,
      'أنت آخر عضو في هذه الشبكة. عند المغادرة سيتم حذف الشبكة بالكامل.',
    );
    expect(
      arabic.cannotLeaveBeforeSettlement,
      'يجب عليك تسوية حساباتك مع أصدقائك أولًا. '
      'يمكنك مغادرة الشبكة بعد أن يصبح إجمالي المصاريف 0.',
    );
  });
}
