import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class AppLocalizations {
  const AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = [
    Locale('en'),
    Locale('ar'),
  ];

  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = [
    AppLocalizationsDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  static const _localizedValues = {
    'en': {
      'appTitle': 'Maskan',
      'homeSubtitle':
          'Create or join a private group and settle shared costs clearly.',
      'createNetwork': 'Create Network',
      'joinNetwork': 'Join Network',
      'displayName': 'User display name',
      'networkName': 'Network name',
      'networkPassword': 'Network password',
      'memberPassword': 'Personal account password',
      'networkCurrency': 'Network currency',
      'currencyHelp': 'All expenses in this network will use this currency.',
      'create': 'Create',
      'join': 'Join',
      'creating': 'Creating...',
      'joining': 'Joining...',
      'members': 'Members',
      'memberStatus': 'Member status',
      'addExpense': 'Add Expense',
      'expenseSettlement': 'Expense Settlement',
      'amount': 'Amount',
      'amountPreview': 'Preview',
      'noteOptional': 'Note / description (optional)',
      'saveExpense': 'Save Expense',
      'saving': 'Saving...',
      'totalExpenses': 'Total expenses',
      'totalPaid': 'Total paid',
      'sharePerMember': 'Share per member',
      'finalSettlement': 'Final settlement',
      'noSettlementNeeded': 'Everyone is settled.',
      'fieldRequired': 'This field is required.',
      'invalidAmount': 'Enter a valid positive amount.',
      'passwordTooShort': 'Password must be at least 4 characters.',
      'noteTooLong': 'Note must be 200 characters or fewer.',
      'paid': 'Paid',
      'shouldPay': 'Should pay',
      'balance': 'Balance',
      'netResult': 'Net result',
      'memberOwes': 'Owes {amount}',
      'memberShouldReceive': 'Should receive {amount}',
      'memberSettled': 'Settled',
      'pays': 'pays',
      'to': 'to',
      'addingExpenseFor': 'Adding expense for {member}',
      'chooseLanguage': 'Choose your language',
      'chooseLanguageSubtitle':
          'Select the language you want to use. You can change this later.',
      'english': 'English',
      'arabic': 'ط§ظ„ط¹ط±ط¨ظٹط©',
      'continueAction': 'Continue',
      'changeLanguage': 'Change language',
      'language': 'Language',
      'myAccount': 'My Account',
      'enterAccount': 'Enter account',
      'selectNetwork': 'Select network',
      'selectMember': 'Select member',
      'accountPassword': 'Account password',
      'noNetworksYet': 'Create or join a network first.',
      'continueToAccount': 'Continue to account',
      'expenseHistory': 'Expense history',
      'noExpensesYet': 'No expenses yet.',
      'noExpensesSubtitle': 'This member has not added any expenses.',
      'note': 'Note',
      'addedBy': 'Added by',
      'notifications': 'Notifications',
      'noNotifications': 'No notifications yet.',
      'markAllRead': 'Mark all read',
      'clear': 'Clear',
      'clearAll': 'Clear all',
      'notificationRemoved': 'Notification removed',
      'newExpenseNotification': '{actor} added {amount}',
      'cloudConnected': 'Cloud connected',
      'cloudConnectionFailedTitle': 'Cloud connection unavailable',
      'cloudConnectionFailedMessage':
          'Maskan stores your network in Supabase only. Check your connection or cloud configuration, then retry.',
      'retry': 'Retry',
      'errorNoInternet':
          'Maskan needs an internet connection. Check your connection and try again.',
      'errorDuplicateNetwork': 'A network with this name already exists.',
      'errorDuplicateMember':
          'This member name is already used in the network.',
      'errorWrongNetworkPassword': 'Network name or password is incorrect.',
      'errorWrongPersonalPassword': 'Personal password is incorrect.',
      'errorSupabasePermission':
          'Cloud access was denied. Check Supabase RLS policies and test credentials.',
      'errorSupabaseNotConfigured':
          'Supabase is not configured for this build.',
      'logout': 'Log out',
      'karamixLabsButtonLabel': 'Karamix Labs',
      'karamixLabsButtonTooltip': 'Open Karamix Labs website',
      'karamixLabsLaunchError':
          'Could not open the Karamix Labs website. Please try again later.',
      'footerText':
          'آ© 2026 ط¹ط¨ط¯ ط§ظ„ظƒط±ظٹظ… ط­ط§ط¬ ظٹط§ط³ظٹظ†. ط¬ظ…ظٹط¹ ط§ظ„ط­ظ‚ظˆظ‚ ظ…ط­ظپظˆط¸ط©.',
      'downloadPdf': 'Download PDF',
      'startNewCycle': 'Start New Cycle',
      'generatedAt': 'Generated at',
      'resetRequestPending': 'Reset request pending',
      'approveReset': 'Approve reset',
      'waitingForMembers': 'Waiting for members',
      'approvedMembers': 'Approved members',
      'pendingMembers': 'Pending members',
      'newCycleStarted': 'New cycle started.',
      'failedToGeneratePdf': 'Failed to generate PDF.',
      'pdfSharedSuccessfully': 'PDF generated successfully.',
      'resetRequestAlreadyPending': 'A reset request is already pending.',
      'resetApprovalFailed': 'Could not approve the reset request.',
      'cycleCompletionFailed': 'Could not start the new cycle.',
      'startNewCycleConfirmation':
          'Do you want to archive old expenses and start a new expense cycle? Nothing will happen until all members approve.',
      'cancel': 'Cancel',
      'confirm': 'Confirm',
      'resetRequestedBy': 'Requested by {member}',
      'resetRequestNotification':
          '{actor} requested starting a new expense cycle.',
      'cycleStartedNotification': 'A new expense cycle has started.',
      'connected': 'Connected',
      'syncing': 'Syncing',
      'offline': 'Offline',
      'reconnecting': 'Reconnecting',
      'inviteMembers': 'Invite Members',
      'scanInvite': 'Scan Invite',
      'invalidInviteQr': 'This QR code is not a valid Maskan invite.',
      'inviteScannerTitle': 'Scan Invite',
      'inviteScannerHint': 'Point the camera at a Maskan invite QR code.',
      'inviteJoinPrefill':
          'Invite detected. Enter your name and passwords to join.',
      'inviteInstructions':
          'Install Maskan first, then open this invite link. If the website page appears, copy the network code and open it in Maskan.',
      'inviteLinkLabel': 'Maskan invite link',
      'joinMyMaskanNetwork': 'Join my Maskan network:',
      'leaveNetwork': 'Leave Network',
      'confirmLeaveNetwork':
          'Do you want to delete your account and permanently leave this expense network?',
      'cannotLeaveBeforeSettlement':
          'You must settle accounts with your friends first. You can leave after the total expenses becomes 0.',
      'cannotLeavePendingReset':
          'Finish the pending new cycle request before leaving this network.',
      'cannotLeaveWithHistory':
          'This account still has expense history in this network. Export or settle records before leaving.',
      'leaveNetworkSuccess': 'You left the network.',
      'leaveNetworkFailed': 'Could not leave the network.',
      'reportSubtitleEn': 'Shared Housing Expense Report',
      'reportSubtitleAr': 'طھظ‚ط±ظٹط± ظ…طµط§ط±ظٹظپ ط§ظ„ط³ظƒظ†',
      'reportNetworkInfo': 'Network info',
      'reportMemberCount': 'Member count',
      'reportSettlementInstructions': 'Settlement instructions',
      'poweredByKaramix': 'Powered by Karamix Labs',
      'copyLink': 'Copy link',
      'share': 'Share',
      'inviteCopied': 'Invite link copied',
      'topPayer': 'Top payer',
      'currentCycleTotal': 'Current cycle',
      'averageExpense': 'Average expense',
      'expenseCount': 'Expenses',
      'monthlySpend': 'This month',
      'activityTimeline': 'Activity timeline',
      'noActivityYet': 'No activity yet.',
      'editAvatar': 'Edit avatar',
      'avatarColor': 'Avatar color',
      'save': 'Save',
      'pushExpenseAddedTitle': 'New expense added',
      'pushResetRequestedTitle': 'New cycle request',
      'pushCycleStartedTitle': 'New cycle started',
    },
    'ar': {
      'appTitle': 'Maskan',
      'homeSubtitle':
          'ط£ظ†ط´ط¦ ظ…ط¬ظ…ظˆط¹ط© ط®ط§طµط© ط£ظˆ ط§ظ†ط¶ظ… ط¥ظ„ظٹظ‡ط§ ظ„طھظ‚ط³ظٹظ… ط§ظ„ظ…طµط§ط±ظٹظپ ظˆطھط³ظˆظٹطھظ‡ط§ ط¨ظˆط¶ظˆط­.',
      'createNetwork': 'ط¥ظ†ط´ط§ط، ط´ط¨ظƒط©',
      'joinNetwork': 'ط§ظ„ط§ظ†ط¶ظ…ط§ظ… ط¥ظ„ظ‰ ط´ط¨ظƒط©',
      'displayName': 'ط§ط³ظ… ط§ظ„ظ…ط³طھط®ط¯ظ… ط§ظ„ط¸ط§ظ‡ط±',
      'networkName': 'ط§ط³ظ… ط§ظ„ط´ط¨ظƒط©',
      'networkPassword': 'ظƒظ„ظ…ط© ظ…ط±ظˆط± ط§ظ„ط´ط¨ظƒط©',
      'memberPassword': 'ظƒظ„ظ…ط© ظ…ط±ظˆط± ط§ظ„ط­ط³ط§ط¨ ط§ظ„ط´ط®طµظٹ',
      'networkCurrency': 'ط¹ظ…ظ„ط© ط§ظ„ط´ط¨ظƒط©',
      'currencyHelp': 'ط³طھط³طھط®ط¯ظ… ط¬ظ…ظٹط¹ ط§ظ„ظ…طµط§ط±ظٹظپ ظپظٹ ظ‡ط°ظ‡ ط§ظ„ط´ط¨ظƒط© ظ‡ط°ظ‡ ط§ظ„ط¹ظ…ظ„ط©.',
      'create': 'ط¥ظ†ط´ط§ط،',
      'join': 'ط§ظ†ط¶ظ…ط§ظ…',
      'creating': 'ط¬ط§ط±ظچ ط§ظ„ط¥ظ†ط´ط§ط،...',
      'joining': 'ط¬ط§ط±ظچ ط§ظ„ط§ظ†ط¶ظ…ط§ظ…...',
      'members': 'ط§ظ„ط£ط¹ط¶ط§ط،',
      'memberStatus': 'ط­ط§ظ„ط© ط§ظ„ط£ط¹ط¶ط§ط،',
      'addExpense': 'ط¥ط¶ط§ظپط© ظ…طµط±ظˆظپ',
      'expenseSettlement': 'طھط³ظˆظٹط© ط§ظ„ظ…طµط§ط±ظٹظپ',
      'amount': 'ط§ظ„ظ…ط¨ظ„ط؛',
      'amountPreview': 'ظ…ط¹ط§ظٹظ†ط©',
      'noteOptional': 'ظ…ظ„ط§ط­ط¸ط© / ظˆطµظپ (ط§ط®طھظٹط§ط±ظٹ)',
      'saveExpense': 'ط­ظپط¸ ط§ظ„ظ…طµط±ظˆظپ',
      'saving': 'ط¬ط§ط±ظچ ط§ظ„ط­ظپط¸...',
      'totalExpenses': 'ط¥ط¬ظ…ط§ظ„ظٹ ط§ظ„ظ…طµط§ط±ظٹظپ',
      'totalPaid': 'ط¥ط¬ظ…ط§ظ„ظٹ ط§ظ„ظ…ط¯ظپظˆط¹',
      'sharePerMember': 'ط­طµط© ظƒظ„ ط¹ط¶ظˆ',
      'finalSettlement': 'ط§ظ„طھط³ظˆظٹط© ط§ظ„ظ†ظ‡ط§ط¦ظٹط©',
      'noSettlementNeeded': 'ط§ظ„ط¬ظ…ظٹط¹ ظ…طھط¹ط§ط¯ظ„ظˆظ†.',
      'fieldRequired': 'ظ‡ط°ط§ ط§ظ„ط­ظ‚ظ„ ظ…ط·ظ„ظˆط¨.',
      'invalidAmount': 'ط£ط¯ط®ظ„ ظ…ط¨ظ„ط؛ظ‹ط§ طµط­ظٹط­ظ‹ط§ ط£ظƒط¨ط± ظ…ظ† طµظپط±.',
      'passwordTooShort': 'ظٹط¬ط¨ ط£ظ† طھظƒظˆظ† ظƒظ„ظ…ط© ط§ظ„ظ…ط±ظˆط± 4 ط£ط­ط±ظپ ط¹ظ„ظ‰ ط§ظ„ط£ظ‚ظ„.',
      'noteTooLong': 'ظٹط¬ط¨ ط£ظ„ط§ طھطھط¬ط§ظˆط² ط§ظ„ظ…ظ„ط§ط­ط¸ط© 200 ط­ط±ظپ.',
      'paid': 'ط¯ظپط¹',
      'shouldPay': 'ط§ظ„ظ…ط³طھط­ظ‚ ط¹ظ„ظٹظ‡',
      'balance': 'ط§ظ„ط±طµظٹط¯',
      'netResult': 'ط§ظ„ظ†طھظٹط¬ط©',
      'memberOwes': 'ط¹ظ„ظٹظ‡ ط£ظ† ظٹط¯ظپط¹ {amount}',
      'memberShouldReceive': 'ظ„ظ‡ ط£ظ† ظٹط³طھظ„ظ… {amount}',
      'memberSettled': 'ظ…طھظˆط§ط²ظ†',
      'pays': 'ظٹط¯ظپط¹',
      'to': 'ط¥ظ„ظ‰',
      'addingExpenseFor': 'ط¥ط¶ط§ظپط© ظ…طµط±ظˆظپ ط¨ط§ط³ظ… {member}',
      'chooseLanguage': 'ط§ط®طھط± ظ„ط؛ط© ط§ظ„طھط·ط¨ظٹظ‚',
      'chooseLanguageSubtitle':
          'ط§ط®طھط± ط§ظ„ظ„ط؛ط© ط§ظ„طھظٹ طھط±ظٹط¯ ط§ط³طھط®ط¯ط§ظ…ظ‡ط§. ظٹظ…ظƒظ†ظƒ طھط؛ظٹظٹط±ظ‡ط§ ظ„ط§ط­ظ‚ظ‹ط§.',
      'english': 'English',
      'arabic': 'ط§ظ„ط¹ط±ط¨ظٹط©',
      'continueAction': 'ظ…طھط§ط¨ط¹ط©',
      'changeLanguage': 'طھط؛ظٹظٹط± ط§ظ„ظ„ط؛ط©',
      'language': 'ط§ظ„ظ„ط؛ط©',
      'myAccount': 'ط­ط³ط§ط¨ظٹ',
      'enterAccount': 'ط§ظ„ط¯ط®ظˆظ„ ط¥ظ„ظ‰ ط§ظ„ط­ط³ط§ط¨',
      'selectNetwork': 'ط§ط®طھط± ط§ظ„ط´ط¨ظƒط©',
      'selectMember': 'ط§ط®طھط± ط§ظ„ط¹ط¶ظˆ',
      'accountPassword': 'ظƒظ„ظ…ط© ظ…ط±ظˆط± ط§ظ„ط­ط³ط§ط¨',
      'noNetworksYet': 'ط£ظ†ط´ط¦ ط´ط¨ظƒط© ط£ظˆ ط§ظ†ط¶ظ… ط¥ظ„ظ‰ ط´ط¨ظƒط© ط£ظˆظ„ظ‹ط§.',
      'continueToAccount': 'ظ…طھط§ط¨ط¹ط© ط¥ظ„ظ‰ ط§ظ„ط­ط³ط§ط¨',
      'expenseHistory': 'ط³ط¬ظ„ ط§ظ„ظ…طµط§ط±ظٹظپ',
      'noExpensesYet': 'ظ„ط§ طھظˆط¬ط¯ ظ…طµط§ط±ظٹظپ ط¨ط¹ط¯.',
      'noExpensesSubtitle': 'ظ„ظ… ظٹط¶ظپ ظ‡ط°ط§ ط§ظ„ط¹ط¶ظˆ ط£ظٹ ظ…طµط§ط±ظٹظپ.',
      'note': 'ظ…ظ„ط§ط­ط¸ط©',
      'addedBy': 'ط£ط¶ط§ظپظ‡ط§',
      'notifications': 'ط§ظ„ط¥ط´ط¹ط§ط±ط§طھ',
      'noNotifications': 'ظ„ط§ طھظˆط¬ط¯ ط¥ط´ط¹ط§ط±ط§طھ ط¨ط¹ط¯.',
      'markAllRead': 'طھط¹ظ„ظٹظ… ط§ظ„ظƒظ„ ظƒظ…ظ‚ط±ظˆط،',
      'clear': 'ظ…ط³ط­',
      'clearAll': 'ظ…ط³ط­ ط§ظ„ظƒظ„',
      'notificationRemoved': 'طھظ…طھ ط¥ط²ط§ظ„ط© ط§ظ„ط¥ط´ط¹ط§ط±',
      'newExpenseNotification': 'ط£ط¶ط§ظپ {actor} {amount}',
      'errorNoInternet':
          'ظٹط­طھط§ط¬ ط§ظ„ظˆط¶ط¹ ط§ظ„ط³ط­ط§ط¨ظٹ ط¥ظ„ظ‰ ط§طھطµط§ظ„ ط¨ط§ظ„ط¥ظ†طھط±ظ†طھ. طھط­ظ‚ظ‚ ظ…ظ† ط§ظ„ط§طھطµط§ظ„ ظˆط­ط§ظˆظ„ ظ…ط±ط© ط£ط®ط±ظ‰.',
      'errorDuplicateNetwork': 'طھظˆط¬ط¯ ط´ط¨ظƒط© ط¨ظ‡ط°ط§ ط§ظ„ط§ط³ظ… ط¨ط§ظ„ظپط¹ظ„.',
      'errorDuplicateMember': 'ط§ط³ظ… ط§ظ„ط¹ط¶ظˆ ظ…ط³طھط®ط¯ظ… ط¨ط§ظ„ظپط¹ظ„ ظپظٹ ظ‡ط°ظ‡ ط§ظ„ط´ط¨ظƒط©.',
      'errorWrongNetworkPassword': 'ط§ط³ظ… ط§ظ„ط´ط¨ظƒط© ط£ظˆ ظƒظ„ظ…ط© ظ…ط±ظˆط± ط§ظ„ط´ط¨ظƒط© ط؛ظٹط± طµط­ظٹط­ط©.',
      'errorWrongPersonalPassword': 'ظƒظ„ظ…ط© ظ…ط±ظˆط± ط§ظ„ط­ط³ط§ط¨ ط§ظ„ط´ط®طµظٹ ط؛ظٹط± طµط­ظٹط­ط©.',
      'errorSupabasePermission':
          'طھظ… ط±ظپط¶ ط§ظ„ظˆطµظˆظ„ ط§ظ„ط³ط­ط§ط¨ظٹ. طھط­ظ‚ظ‚ ظ…ظ† ط³ظٹط§ط³ط§طھ Supabase RLS ظˆط¨ظٹط§ظ†ط§طھ ط§ظ„ط§ط®طھط¨ط§ط±.',
      'errorSupabaseNotConfigured':
          'ظˆط¶ط¹ ط§ظ„ط§ط®طھط¨ط§ط± ط§ظ„ط³ط­ط§ط¨ظٹ ط؛ظٹط± ظ…ظ‡ظٹط£ ظپظٹ ظ‡ط°ط§ ط§ظ„ط¥طµط¯ط§ط±.',
      'logout': 'طھط³ط¬ظٹظ„ ط§ظ„ط®ط±ظˆط¬',
      'karamixLabsButtonLabel': 'Karamix Labs',
      'karamixLabsButtonTooltip': 'ظپطھط­ ظ…ظˆظ‚ط¹ Karamix Labs',
      'karamixLabsLaunchError':
          'طھط¹ط°ط± ظپطھط­ ظ…ظˆظ‚ط¹ Karamix Labs. ظٹط±ط¬ظ‰ ط§ظ„ظ…ط­ط§ظˆظ„ط© ظ„ط§ط­ظ‚ط§.',
      'footerText':
          'آ© 2026 ط¹ط¨ط¯ ط§ظ„ظƒط±ظٹظ… ط­ط§ط¬ ظٹط§ط³ظٹظ†. ط¬ظ…ظٹط¹ ط§ظ„ط­ظ‚ظˆظ‚ ظ…ط­ظپظˆط¸ط©.',
      'downloadPdf': 'طھط­ظ…ظٹظ„ PDF',
      'startNewCycle': 'ط¨ط¯ط، ظ…طµط±ظˆظپ ط¬ط¯ظٹط¯',
      'generatedAt': 'طھط§ط±ظٹط® ط§ظ„ط¥ظ†ط´ط§ط،',
      'resetRequestPending': 'ط·ظ„ط¨ ط§ظ„ط¨ط¯ط، ط§ظ„ط¬ط¯ظٹط¯ ط¨ط§ظ†طھط¸ط§ط± ط§ظ„ظ…ظˆط§ظپظ‚ط©',
      'approveReset': 'ط§ظ„ظ…ظˆط§ظپظ‚ط© ط¹ظ„ظ‰ ط§ظ„ط·ظ„ط¨',
      'waitingForMembers': 'ط¨ط§ظ†طھط¸ط§ط± ط§ظ„ط£ط¹ط¶ط§ط،',
      'approvedMembers': 'ط§ظ„ط£ط¹ط¶ط§ط، ط§ظ„ظ…ظˆط§ظپظ‚ظˆظ†',
      'pendingMembers': 'ط§ظ„ط£ط¹ط¶ط§ط، ط¨ط§ظ†طھط¸ط§ط± ط§ظ„ظ…ظˆط§ظپظ‚ط©',
      'newCycleStarted': 'طھظ… ط¨ط¯ط، ظ…طµط±ظˆظپ ط¬ط¯ظٹط¯.',
      'failedToGeneratePdf': 'طھط¹ط°ط± ط¥ظ†ط´ط§ط، ظ…ظ„ظپ PDF.',
      'pdfSharedSuccessfully': 'طھظ… ط¥ظ†ط´ط§ط، ظ…ظ„ظپ PDF ط¨ظ†ط¬ط§ط­.',
      'resetRequestAlreadyPending': 'ظٹظˆط¬ط¯ ط·ظ„ط¨ ط¨ط¯ط، ط¬ط¯ظٹط¯ ط¨ط§ظ†طھط¸ط§ط± ط§ظ„ظ…ظˆط§ظپظ‚ط©.',
      'resetApprovalFailed': 'طھط¹ط°ط±طھ ط§ظ„ظ…ظˆط§ظپظ‚ط© ط¹ظ„ظ‰ ط·ظ„ط¨ ط§ظ„ط¨ط¯ط، ط§ظ„ط¬ط¯ظٹط¯.',
      'cycleCompletionFailed': 'طھط¹ط°ط± ط¨ط¯ط، ط§ظ„ظ…طµط±ظˆظپ ط§ظ„ط¬ط¯ظٹط¯.',
      'startNewCycleConfirmation':
          'ظ‡ظ„ طھط±ظٹط¯ ط·ظ„ط¨ ط­ط°ظپ/ط£ط±ط´ظپط© ط§ظ„ظ…طµط§ط±ظٹظپ ط§ظ„ظ‚ط¯ظٹظ…ط© ظˆط¨ط¯ط، ظ…طµط±ظˆظپ ط¬ط¯ظٹط¯طں ظ„ظ† ظٹطھظ… ط§ظ„طھظ†ظپظٹط° ط­طھظ‰ ظٹظˆط§ظپظ‚ ط¬ظ…ظٹط¹ ط§ظ„ط£ط¹ط¶ط§ط،.',
      'cancel': 'ط¥ظ„ط؛ط§ط،',
      'confirm': 'طھط£ظƒظٹط¯',
      'resetRequestedBy': 'ط·ظ„ط¨ظ‡ {member}',
      'resetRequestNotification': 'ط·ظ„ط¨ {actor} ط¨ط¯ط، ظ…طµط±ظˆظپ ط¬ط¯ظٹط¯.',
      'cycleStartedNotification': 'طھظ… ط¨ط¯ط، ظ…طµط±ظˆظپ ط¬ط¯ظٹط¯.',
      'connected': 'ظ…طھطµظ„',
      'syncing': 'ط¬ط§ط± ط§ظ„ظ…ط²ط§ظ…ظ†ط©',
      'offline': 'ط؛ظٹط± ظ…طھطµظ„',
      'inviteMembers': 'ط¯ط¹ظˆط© ط£ط¹ط¶ط§ط،',
      'scanInvite': 'ظ…ط³ط­ ط¯ط¹ظˆط©',
      'invalidInviteQr': 'ط±ظ…ط² QR ظ‡ط°ط§ ظ„ظٹط³ ط¯ط¹ظˆط© Maskan طµط§ظ„ط­ط©.',
      'inviteScannerTitle': 'ظ…ط³ط­ ط¯ط¹ظˆط©',
      'inviteScannerHint': 'ظˆط¬ظ‘ظ‡ ط§ظ„ظƒط§ظ…ظٹط±ط§ ط¥ظ„ظ‰ ط±ظ…ط² ط¯ط¹ظˆط© Maskan.',
      'inviteJoinPrefill':
          'طھظ… ط§ظƒطھط´ط§ظپ ط§ظ„ط¯ط¹ظˆط©. ط£ط¯ط®ظ„ ط§ط³ظ…ظƒ ظˆظƒظ„ظ…ط§طھ ط§ظ„ظ…ط±ظˆط± ظ„ظ„ط§ظ†ط¶ظ…ط§ظ….',
      'inviteInstructions':
          'ط«ط¨ظ‘طھ Maskan ط£ظˆظ„ط§ظ‹طŒ ط«ظ… ط§ظپطھط­ ط±ط§ط¨ط· ط§ظ„ط¯ط¹ظˆط©. ط¥ط°ط§ ط¸ظ‡ط±طھ طµظپط­ط© ط§ظ„ظ…ظˆظ‚ط¹طŒ ط§ظ†ط³ط® ط±ظ…ط² ط§ظ„ط´ط¨ظƒط© ظˆط§ظپطھط­ظ‡ ظپظٹ Maskan.',
      'inviteLinkLabel': 'ط±ط§ط¨ط· ط¯ط¹ظˆط© Maskan',
      'joinMyMaskanNetwork': 'ط§ظ†ط¶ظ… ط¥ظ„ظ‰ ط´ط¨ظƒطھظٹ ظپظٹ Maskan:',
      'leaveNetwork': 'ظ…ط؛ط§ط¯ط±ط© ط§ظ„ط´ط¨ظƒط©',
      'confirmLeaveNetwork':
          'ظ‡ظ„ طھط±ظٹط¯ ط­ط°ظپ ط­ط³ط§ط¨ظƒ ظˆظ…ط؛ط§ط¯ط±ط© ط´ط¨ظƒط© ط§ظ„ظ…طµط±ظˆظپ ظ†ظ‡ط§ط¦ظٹظ‹ط§طں',
      'cannotLeaveBeforeSettlement':
          'ظٹط¬ط¨ ط¹ظ„ظٹظƒ طھط³ظˆظٹط© ط­ط³ط§ط¨ط§طھظƒ ظ…ط¹ ط£طµط¯ظ‚ط§ط¦ظƒ ط£ظˆظ„ظ‹ط§. ظٹظ…ظƒظ†ظƒ ظ…ط؛ط§ط¯ط±ط© ط§ظ„ط´ط¨ظƒط© ط¨ط¹ط¯ ط£ظ† ظٹطµط¨ط­ ط¥ط¬ظ…ط§ظ„ظٹ ط§ظ„ظ…طµط§ط±ظٹظپ 0.',
      'cannotLeavePendingReset':
          'ط£ظƒظ…ظ„ ط·ظ„ط¨ ط¨ط¯ط، ط§ظ„ط¯ظˆط±ط© ط§ظ„ط¬ط¯ظٹط¯ط© ط§ظ„ظ…ط¹ظ„ظ‚ ظ‚ط¨ظ„ ظ…ط؛ط§ط¯ط±ط© ظ‡ط°ظ‡ ط§ظ„ط´ط¨ظƒط©.',
      'cannotLeaveWithHistory':
          'ظ„ط§ ظٹط²ط§ظ„ ظ„ظ‡ط°ط§ ط§ظ„ط­ط³ط§ط¨ ط³ط¬ظ„ ظ…طµط§ط±ظٹظپ ظپظٹ ظ‡ط°ظ‡ ط§ظ„ط´ط¨ظƒط©. طµط¯ظ‘ط± ط§ظ„ط³ط¬ظ„ط§طھ ط£ظˆ ط³ظˆظ‘ظ‡ط§ ظ‚ط¨ظ„ ط§ظ„ظ…ط؛ط§ط¯ط±ط©.',
      'leaveNetworkSuccess': 'طھظ…طھ ظ…ط؛ط§ط¯ط±ط© ط§ظ„ط´ط¨ظƒط©.',
      'leaveNetworkFailed': 'طھط¹ط°ط± ظ…ط؛ط§ط¯ط±ط© ط§ظ„ط´ط¨ظƒط©.',
      'reportSubtitleEn': 'Shared Housing Expense Report',
      'reportSubtitleAr': 'طھظ‚ط±ظٹط± ظ…طµط§ط±ظٹظپ ط§ظ„ط³ظƒظ†',
      'reportNetworkInfo': 'ظ…ط¹ظ„ظˆظ…ط§طھ ط§ظ„ط´ط¨ظƒط©',
      'reportMemberCount': 'ط¹ط¯ط¯ ط§ظ„ط£ط¹ط¶ط§ط،',
      'reportSettlementInstructions': 'طھط¹ظ„ظٹظ…ط§طھ ط§ظ„طھط³ظˆظٹط©',
      'poweredByKaramix': 'ط¨ط¯ط¹ظ… ظ…ظ† Karamix Labs',
      'copyLink': 'ظ†ط³ط® ط§ظ„ط±ط§ط¨ط·',
      'share': 'ظ…ط´ط§ط±ظƒط©',
      'inviteCopied': 'طھظ… ظ†ط³ط® ط±ط§ط¨ط· ط§ظ„ط¯ط¹ظˆط©',
      'topPayer': 'ط§ظ„ط£ظƒط«ط± ط¯ظپط¹ط§',
      'currentCycleTotal': 'ط§ظ„ط¯ظˆط±ط© ط§ظ„ط­ط§ظ„ظٹط©',
      'averageExpense': 'ظ…طھظˆط³ط· ط§ظ„ظ…طµط±ظˆظپ',
      'expenseCount': 'ط¹ط¯ط¯ ط§ظ„ظ…طµط§ط±ظٹظپ',
      'monthlySpend': 'ظ‡ط°ط§ ط§ظ„ط´ظ‡ط±',
      'activityTimeline': 'ط³ط¬ظ„ ط§ظ„ظ†ط´ط§ط·',
      'noActivityYet': 'ظ„ط§ ظٹظˆط¬ط¯ ظ†ط´ط§ط· ط¨ط¹ط¯.',
      'editAvatar': 'طھط¹ط¯ظٹظ„ ط§ظ„طµظˆط±ط©',
      'avatarColor': 'ظ„ظˆظ† ط§ظ„طµظˆط±ط©',
      'save': 'ط­ظپط¸',
      'pushExpenseAddedTitle': 'طھظ…طھ ط¥ط¶ط§ظپط© ظ…طµط±ظˆظپ ط¬ط¯ظٹط¯',
      'pushResetRequestedTitle': 'ط·ظ„ط¨ ط¨ط¯ط، ظ…طµط±ظˆظپ ط¬ط¯ظٹط¯',
      'pushCycleStartedTitle': 'طھظ… ط¨ط¯ط، ظ…طµط±ظˆظپ ط¬ط¯ظٹط¯',
    },
  };

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static bool isSupportedLanguageCode(String value) {
    return supportedLocales.any((locale) => locale.languageCode == value);
  }

  String _text(String key) {
    return _localizedValues[locale.languageCode]?[key] ??
        _localizedValues['en']![key]!;
  }

  String get appTitle => _text('appTitle');
  String get homeSubtitle => _text('homeSubtitle');
  String get createNetwork => _text('createNetwork');
  String get joinNetwork => _text('joinNetwork');
  String get displayName => _text('displayName');
  String get networkName => _text('networkName');
  String get networkPassword => _text('networkPassword');
  String get memberPassword => _text('memberPassword');
  String get networkCurrency => _text('networkCurrency');
  String get currencyHelp => _text('currencyHelp');
  String get create => _text('create');
  String get join => _text('join');
  String get creating => _text('creating');
  String get joining => _text('joining');
  String get members => _text('members');
  String get memberStatus => _text('memberStatus');
  String get addExpense => _text('addExpense');
  String get expenseSettlement => _text('expenseSettlement');
  String get amount => _text('amount');
  String get amountPreview => _text('amountPreview');
  String get noteOptional => _text('noteOptional');
  String get saveExpense => _text('saveExpense');
  String get saving => _text('saving');
  String get totalExpenses => _text('totalExpenses');
  String get totalPaid => _text('totalPaid');
  String get sharePerMember => _text('sharePerMember');
  String get finalSettlement => _text('finalSettlement');
  String get noSettlementNeeded => _text('noSettlementNeeded');
  String get fieldRequired => _text('fieldRequired');
  String get invalidAmount => _text('invalidAmount');
  String get passwordTooShort => _text('passwordTooShort');
  String get noteTooLong => _text('noteTooLong');
  String get paid => _text('paid');
  String get shouldPay => _text('shouldPay');
  String get balance => _text('balance');
  String get netResult => _text('netResult');
  String get pays => _text('pays');
  String get to => _text('to');
  String get chooseLanguage => _text('chooseLanguage');
  String get chooseLanguageSubtitle => _text('chooseLanguageSubtitle');
  String get english => _text('english');
  String get arabic => _text('arabic');
  String get continueAction => _text('continueAction');
  String get changeLanguage => _text('changeLanguage');
  String get language => _text('language');
  String get myAccount => _text('myAccount');
  String get enterAccount => _text('enterAccount');
  String get selectNetwork => _text('selectNetwork');
  String get selectMember => _text('selectMember');
  String get accountPassword => _text('accountPassword');
  String get noNetworksYet => _text('noNetworksYet');
  String get continueToAccount => _text('continueToAccount');
  String get expenseHistory => _text('expenseHistory');
  String get noExpensesYet => _text('noExpensesYet');
  String get noExpensesSubtitle => _text('noExpensesSubtitle');
  String get note => _text('note');
  String get addedBy => _text('addedBy');
  String get notifications => _text('notifications');
  String get noNotifications => _text('noNotifications');
  String get markAllRead => _text('markAllRead');
  String get clear => _text('clear');
  String get clearAll => _text('clearAll');
  String get notificationRemoved => _text('notificationRemoved');
  String get cloudConnected => _text('cloudConnected');
  String get cloudConnectionFailedTitle => _text('cloudConnectionFailedTitle');
  String get cloudConnectionFailedMessage =>
      _text('cloudConnectionFailedMessage');
  String get retry => _text('retry');
  String get errorNoInternet => _text('errorNoInternet');
  String get errorDuplicateNetwork => _text('errorDuplicateNetwork');
  String get errorDuplicateMember => _text('errorDuplicateMember');
  String get errorWrongNetworkPassword => _text('errorWrongNetworkPassword');
  String get errorWrongPersonalPassword => _text('errorWrongPersonalPassword');
  String get errorSupabasePermission => _text('errorSupabasePermission');
  String get errorSupabaseNotConfigured => _text('errorSupabaseNotConfigured');
  String get logout => _text('logout');
  String get karamixLabsButtonLabel => _text('karamixLabsButtonLabel');
  String get karamixLabsButtonTooltip => _text('karamixLabsButtonTooltip');
  String get karamixLabsLaunchError => _text('karamixLabsLaunchError');
  String get footerText => _text('footerText');
  String get downloadPdf => _text('downloadPdf');
  String get startNewCycle => _text('startNewCycle');
  String get generatedAt => _text('generatedAt');
  String get resetRequestPending => _text('resetRequestPending');
  String get approveReset => _text('approveReset');
  String get waitingForMembers => _text('waitingForMembers');
  String get approvedMembers => _text('approvedMembers');
  String get pendingMembers => _text('pendingMembers');
  String get newCycleStarted => _text('newCycleStarted');
  String get failedToGeneratePdf => _text('failedToGeneratePdf');
  String get pdfSharedSuccessfully => _text('pdfSharedSuccessfully');
  String get resetRequestAlreadyPending => _text('resetRequestAlreadyPending');
  String get resetApprovalFailed => _text('resetApprovalFailed');
  String get cycleCompletionFailed => _text('cycleCompletionFailed');
  String get startNewCycleConfirmation => _text('startNewCycleConfirmation');
  String get cancel => _text('cancel');
  String get confirm => _text('confirm');
  String get cycleStartedNotification => _text('cycleStartedNotification');
  String get connected => _text('connected');
  String get syncing => _text('syncing');
  String get offline => _text('offline');
  String get reconnecting => _text('reconnecting');
  String get inviteMembers => _text('inviteMembers');
  String get scanInvite => _text('scanInvite');
  String get invalidInviteQr => _text('invalidInviteQr');
  String get inviteScannerTitle => _text('inviteScannerTitle');
  String get inviteScannerHint => _text('inviteScannerHint');
  String get inviteJoinPrefill => _text('inviteJoinPrefill');
  String get inviteInstructions => _text('inviteInstructions');
  String get inviteLinkLabel => _text('inviteLinkLabel');
  String get joinMyMaskanNetwork => _text('joinMyMaskanNetwork');
  String get leaveNetwork => _text('leaveNetwork');
  String get confirmLeaveNetwork => _text('confirmLeaveNetwork');
  String get cannotLeaveBeforeSettlement => _text('cannotLeaveBeforeSettlement');
  String get cannotLeavePendingReset => _text('cannotLeavePendingReset');
  String get cannotLeaveWithHistory => _text('cannotLeaveWithHistory');
  String get leaveNetworkSuccess => _text('leaveNetworkSuccess');
  String get leaveNetworkFailed => _text('leaveNetworkFailed');
  String get reportSubtitleEn => _text('reportSubtitleEn');
  String get reportSubtitleAr => _text('reportSubtitleAr');
  String get reportNetworkInfo => _text('reportNetworkInfo');
  String get reportMemberCount => _text('reportMemberCount');
  String get reportSettlementInstructions =>
      _text('reportSettlementInstructions');
  String get poweredByKaramix => _text('poweredByKaramix');
  String get copyLink => _text('copyLink');
  String get share => _text('share');
  String get inviteCopied => _text('inviteCopied');
  String get topPayer => _text('topPayer');
  String get currentCycleTotal => _text('currentCycleTotal');
  String get averageExpense => _text('averageExpense');
  String get expenseCount => _text('expenseCount');
  String get monthlySpend => _text('monthlySpend');
  String get activityTimeline => _text('activityTimeline');
  String get noActivityYet => _text('noActivityYet');
  String get editAvatar => _text('editAvatar');
  String get avatarColor => _text('avatarColor');
  String get save => _text('save');
  String get pushExpenseAddedTitle => _text('pushExpenseAddedTitle');
  String get pushResetRequestedTitle => _text('pushResetRequestedTitle');
  String get pushCycleStartedTitle => _text('pushCycleStartedTitle');

  String addingExpenseFor(String memberName) {
    return _text('addingExpenseFor').replaceAll('{member}', memberName);
  }

  String settlementPayment({
    required String fromMember,
    required String amount,
    required String toMember,
  }) {
    return '$fromMember $pays $amount $to $toMember';
  }

  String memberOwes(String amount) {
    return _text('memberOwes').replaceAll('{amount}', amount);
  }

  String memberShouldReceive(String amount) {
    return _text('memberShouldReceive').replaceAll('{amount}', amount);
  }

  String get memberSettled => _text('memberSettled');

  String newExpenseNotification({
    required String actor,
    required String amount,
  }) {
    return _text('newExpenseNotification')
        .replaceAll('{actor}', actor)
        .replaceAll('{amount}', amount);
  }

  String resetRequestedBy(String memberName) {
    return _text('resetRequestedBy').replaceAll('{member}', memberName);
  }

  String resetRequestNotification({
    required String actor,
  }) {
    return _text('resetRequestNotification').replaceAll('{actor}', actor);
  }
}

class AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return AppLocalizations.isSupportedLanguageCode(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) {
    final languageCode =
        AppLocalizations.isSupportedLanguageCode(locale.languageCode)
            ? locale.languageCode
            : 'en';
    return SynchronousFuture(AppLocalizations(Locale(languageCode)));
  }

  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}

extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
