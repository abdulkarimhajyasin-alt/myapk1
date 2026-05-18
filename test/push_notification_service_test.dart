import 'package:expense_network/l10n/app_localizations.dart';
import 'package:expense_network/models/network_notification.dart';
import 'package:expense_network/services/push_notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formats localized notification titles', () {
    final service = PushNotificationService();
    final expense = NetworkNotification(
      networkId: 'network',
      recipientMemberId: 'mona',
      actorMemberName: 'Ali',
      expenseAmountCents: 1000,
      currencySymbol: r'$',
    );
    final reset = NetworkNotification(
      networkId: 'network',
      recipientMemberId: 'mona',
      actorMemberName: 'Ali',
      expenseAmountCents: 0,
      currencySymbol: r'$',
      kind: NetworkNotificationKind.resetRequest,
    );

    expect(
      service
          .copyFor(
            notification: expense,
            l10n: const AppLocalizations(Locale('en')),
          )
          .title,
      'New expense added',
    );
    expect(
      service
          .copyFor(
            notification: reset,
            l10n: const AppLocalizations(Locale('ar')),
          )
          .title,
      'طلب بدء مصروف جديد',
    );
  });

  test('excludes actor from local push notification display', () {
    final service = PushNotificationService();

    expect(
      service.shouldShowFor(
        currentMemberId: 'member_1',
        actorMemberId: 'member_1',
      ),
      isFalse,
    );
    expect(
      service.shouldShowFor(
        currentMemberId: 'member_1',
        actorMemberId: 'member_2',
      ),
      isTrue,
    );
  });
}
