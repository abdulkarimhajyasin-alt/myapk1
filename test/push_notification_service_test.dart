import 'package:expense_network/l10n/app_localizations.dart';
import 'package:expense_network/models/network_notification.dart';
import 'package:expense_network/services/push_notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formats localized notification copy for cloud notifications', () {
    final service = PushNotificationService();
    const english = AppLocalizations(Locale('en'));
    const arabic = AppLocalizations(Locale('ar'));
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
    final cycleStarted = NetworkNotification(
      networkId: 'network',
      recipientMemberId: 'mona',
      actorMemberName: 'System',
      expenseAmountCents: 0,
      currencySymbol: r'$',
      kind: NetworkNotificationKind.cycleStarted,
    );

    final expenseCopy = service.copyFor(notification: expense, l10n: english);
    final resetCopy = service.copyFor(notification: reset, l10n: arabic);
    final cycleCopy =
        service.copyFor(notification: cycleStarted, l10n: english);

    expect(expenseCopy.title, english.pushExpenseAddedTitle);
    expect(expenseCopy.body, 'Ali');
    expect(resetCopy.title, arabic.pushResetRequestedTitle);
    expect(resetCopy.body, 'Ali');
    expect(cycleCopy.title, english.pushCycleStartedTitle);
    expect(cycleCopy.body, 'System');
  });

  test('excludes actor from cloud push notification display', () {
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
    expect(
      service.shouldShowFor(
        currentMemberId: 'member_1',
        actorMemberId: null,
      ),
      isTrue,
    );
  });
}
