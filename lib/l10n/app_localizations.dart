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
      'restoringSessionTitle': 'Restoring your session',
      'restoringSessionMessage':
          'Checking your saved network and taking you back in.',
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
      'arabic': 'العربية',
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
      'errorDuplicateNetwork':
          'This network name is already in use. Choose another name.',
      'errorDuplicateMember':
          'This member name is already used in the network.',
      'errorWrongNetworkPassword': 'Network name or password is incorrect.',
      'errorWrongPersonalPassword': 'Personal password is incorrect.',
      'errorSupabasePermission':
          'Cloud access was denied. Check Supabase RLS policies and test credentials.',
      'errorCloudRecordUnavailable':
          'This saved network is no longer available. Please create or join a network again.',
      'errorCreateNetworkFailed':
          'Could not create the network. Please try again.',
      'errorSupabaseNotConfigured': 'Supabase configuration missing',
      'supabaseConfigurationMissingMessage':
          'This build is missing the Supabase URL or anon key.',
      'logout': 'Log out',
      'karamixLabsButtonLabel': 'Karamix Labs',
      'karamixLabsButtonTooltip': 'Open Karamix Labs website',
      'karamixLabsLaunchError':
          'Could not open the Karamix Labs website. Please try again later.',
      'footerText': '© 2026 عبد الكريم حاج ياسين. جميع الحقوق محفوظة.',
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
      'lastMemberLeaveWarning':
          'You are the last member. Leaving will permanently delete this network.',
      'cannotLeaveBeforeSettlement':
          'You must settle accounts with your friends first. You can leave after the total expenses becomes 0.',
      'cannotLeavePendingReset':
          'Finish the pending new cycle request before leaving this network.',
      'cannotLeaveWithHistory':
          'This account still has expense history in this network. Export or settle records before leaving.',
      'leaveNetworkSuccess': 'You left the network.',
      'leaveNetworkFailed': 'Could not leave the network.',
      'reportSubtitleEn': 'Shared Housing Expense Report',
      'reportSubtitleAr': 'تقرير مصاريف السكن',
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
      'avatarPhotoPermissionDenied':
          'Photo access was denied. Allow gallery access and try again.',
      'avatarPhotoMissing': 'No photo was selected. Choose a photo to update.',
      'avatarPhotoPickFailed':
          'Could not open the photo picker. Please try again.',
      'avatarPhotoTooLarge':
          'This photo is too large. Choose a smaller photo and try again.',
      'avatarPhotoUploadFailed':
          'Could not upload your profile photo. Please try again.',
      'avatarPhotoAuthRequired':
          'Your secure session is not ready. Please reopen the app and try again.',
      'avatarPhotoStorageNotConfigured':
          'Profile photo storage is not configured. Contact support.',
      'avatarPhotoStoragePermissionDenied':
          'Cloud storage denied this photo update. Contact support.',
      'avatarPhotoProfileUpdateFailed':
          'Photo uploaded, but your account could not be updated. Please try again.',
      'avatarColor': 'Avatar color',
      'save': 'Save',
      'pushExpenseAddedTitle': 'New expense added',
      'pushResetRequestedTitle': 'New cycle request',
      'pushCycleStartedTitle': 'New cycle started',
    },
    'ar': {
      'appTitle': 'Maskan',
      'homeSubtitle':
          'أنشئ مجموعة خاصة أو انضم إليها لتقسيم المصاريف وتسويتها بوضوح.',
      'createNetwork': 'إنشاء شبكة',
      'joinNetwork': 'الانضمام إلى شبكة',
      'displayName': 'اسم المستخدم الظاهر',
      'networkName': 'اسم الشبكة',
      'networkPassword': 'كلمة مرور الشبكة',
      'memberPassword': 'كلمة مرور الحساب الشخصي',
      'networkCurrency': 'عملة الشبكة',
      'currencyHelp': 'ستستخدم جميع المصاريف في هذه الشبكة هذه العملة.',
      'create': 'إنشاء',
      'join': 'انضمام',
      'creating': 'جارٍ الإنشاء...',
      'joining': 'جارٍ الانضمام...',
      'members': 'الأعضاء',
      'memberStatus': 'حالة الأعضاء',
      'addExpense': 'إضافة مصروف',
      'expenseSettlement': 'تسوية المصاريف',
      'amount': 'المبلغ',
      'amountPreview': 'معاينة',
      'noteOptional': 'ملاحظة / وصف (اختياري)',
      'saveExpense': 'حفظ المصروف',
      'saving': 'جارٍ الحفظ...',
      'totalExpenses': 'إجمالي المصاريف',
      'totalPaid': 'إجمالي المدفوع',
      'sharePerMember': 'حصة كل عضو',
      'finalSettlement': 'التسوية النهائية',
      'noSettlementNeeded': 'الجميع متعادلون.',
      'fieldRequired': 'هذا الحقل مطلوب.',
      'invalidAmount': 'أدخل مبلغًا صحيحًا أكبر من صفر.',
      'passwordTooShort': 'يجب أن تكون كلمة المرور 4 أحرف على الأقل.',
      'noteTooLong': 'يجب ألا تتجاوز الملاحظة 200 حرف.',
      'paid': 'دفع',
      'shouldPay': 'المستحق عليه',
      'balance': 'الرصيد',
      'netResult': 'النتيجة',
      'memberOwes': 'عليه أن يدفع {amount}',
      'memberShouldReceive': 'له أن يستلم {amount}',
      'memberSettled': 'متوازن',
      'pays': 'يدفع',
      'to': 'إلى',
      'addingExpenseFor': 'إضافة مصروف باسم {member}',
      'chooseLanguage': 'اختر لغة التطبيق',
      'chooseLanguageSubtitle':
          'اختر اللغة التي تريد استخدامها. يمكنك تغييرها لاحقًا.',
      'english': 'English',
      'arabic': 'العربية',
      'continueAction': 'متابعة',
      'changeLanguage': 'تغيير اللغة',
      'language': 'اللغة',
      'myAccount': 'حسابي',
      'enterAccount': 'الدخول إلى الحساب',
      'selectNetwork': 'اختر الشبكة',
      'selectMember': 'اختر العضو',
      'accountPassword': 'كلمة مرور الحساب',
      'noNetworksYet': 'أنشئ شبكة أو انضم إلى شبكة أولًا.',
      'continueToAccount': 'متابعة إلى الحساب',
      'expenseHistory': 'سجل المصاريف',
      'noExpensesYet': 'لا توجد مصاريف بعد.',
      'noExpensesSubtitle': 'لم يضف هذا العضو أي مصاريف.',
      'note': 'ملاحظة',
      'addedBy': 'أضافها',
      'notifications': 'الإشعارات',
      'noNotifications': 'لا توجد إشعارات بعد.',
      'markAllRead': 'تعليم الكل كمقروء',
      'clear': 'مسح',
      'clearAll': 'مسح الكل',
      'notificationRemoved': 'تمت إزالة الإشعار',
      'newExpenseNotification': 'أضاف {actor} {amount}',
      'errorNoInternet':
          'يحتاج الوضع السحابي إلى اتصال بالإنترنت. تحقق من الاتصال وحاول مرة أخرى.',
      'errorDuplicateNetwork': 'اسم الشبكة مستخدم بالفعل. اختر اسمًا آخر.',
      'errorDuplicateMember': 'اسم العضو مستخدم بالفعل في هذه الشبكة.',
      'errorWrongNetworkPassword': 'اسم الشبكة أو كلمة مرور الشبكة غير صحيحة.',
      'errorWrongPersonalPassword': 'كلمة مرور الحساب الشخصي غير صحيحة.',
      'errorSupabasePermission':
          'تم رفض الوصول السحابي. تحقق من سياسات Supabase RLS وبيانات الاختبار.',
      'errorCloudRecordUnavailable':
          'هذه الشبكة المحفوظة لم تعد متاحة. أنشئ شبكة أو انضم إلى شبكة مرة أخرى.',
      'errorCreateNetworkFailed': 'تعذر إنشاء الشبكة. حاول مرة أخرى.',
      'errorSupabaseNotConfigured': 'إعداد Supabase مفقود',
      'supabaseConfigurationMissingMessage':
          'يفتقد هذا الإصدار رابط Supabase أو مفتاح anon.',
      'logout': 'تسجيل الخروج',
      'karamixLabsButtonLabel': 'Karamix Labs',
      'karamixLabsButtonTooltip': 'فتح موقع Karamix Labs',
      'karamixLabsLaunchError':
          'تعذر فتح موقع Karamix Labs. يرجى المحاولة لاحقا.',
      'footerText': '© 2026 عبد الكريم حاج ياسين. جميع الحقوق محفوظة.',
      'downloadPdf': 'تحميل PDF',
      'startNewCycle': 'بدء مصروف جديد',
      'generatedAt': 'تاريخ الإنشاء',
      'resetRequestPending': 'طلب البدء الجديد بانتظار الموافقة',
      'approveReset': 'الموافقة على الطلب',
      'waitingForMembers': 'بانتظار الأعضاء',
      'approvedMembers': 'الأعضاء الموافقون',
      'pendingMembers': 'الأعضاء بانتظار الموافقة',
      'newCycleStarted': 'تم بدء مصروف جديد.',
      'failedToGeneratePdf': 'تعذر إنشاء ملف PDF.',
      'pdfSharedSuccessfully': 'تم إنشاء ملف PDF بنجاح.',
      'resetRequestAlreadyPending': 'يوجد طلب بدء جديد بانتظار الموافقة.',
      'resetApprovalFailed': 'تعذرت الموافقة على طلب البدء الجديد.',
      'cycleCompletionFailed': 'تعذر بدء المصروف الجديد.',
      'startNewCycleConfirmation':
          'هل تريد طلب حذف/أرشفة المصاريف القديمة وبدء مصروف جديد؟ لن يتم التنفيذ حتى يوافق جميع الأعضاء.',
      'cancel': 'إلغاء',
      'confirm': 'تأكيد',
      'resetRequestedBy': 'طلبه {member}',
      'resetRequestNotification': 'طلب {actor} بدء مصروف جديد.',
      'cycleStartedNotification': 'تم بدء مصروف جديد.',
      'connected': 'متصل',
      'syncing': 'جار المزامنة',
      'offline': 'غير متصل',
      'inviteMembers': 'دعوة أعضاء',
      'scanInvite': 'مسح دعوة',
      'invalidInviteQr': 'رمز QR هذا ليس دعوة Maskan صالحة.',
      'inviteScannerTitle': 'مسح دعوة',
      'inviteScannerHint': 'وجّه الكاميرا إلى رمز دعوة Maskan.',
      'inviteJoinPrefill':
          'تم اكتشاف الدعوة. أدخل اسمك وكلمات المرور للانضمام.',
      'inviteInstructions':
          'ثبّت Maskan أولاً، ثم افتح رابط الدعوة. إذا ظهرت صفحة الموقع، انسخ رمز الشبكة وافتحه في Maskan.',
      'inviteLinkLabel': 'رابط دعوة Maskan',
      'joinMyMaskanNetwork': 'انضم إلى شبكتي في Maskan:',
      'leaveNetwork': 'مغادرة الشبكة',
      'confirmLeaveNetwork': 'هل تريد حذف حسابك ومغادرة شبكة المصروف نهائيًا؟',
      'lastMemberLeaveWarning':
          'أنت آخر عضو في هذه الشبكة. عند المغادرة سيتم حذف الشبكة بالكامل.',
      'cannotLeaveBeforeSettlement':
          'يجب عليك تسوية حساباتك مع أصدقائك أولًا. يمكنك مغادرة الشبكة بعد أن يصبح إجمالي المصاريف 0.',
      'cannotLeavePendingReset':
          'أكمل طلب بدء الدورة الجديدة المعلق قبل مغادرة هذه الشبكة.',
      'cannotLeaveWithHistory':
          'لا يزال لهذا الحساب سجل مصاريف في هذه الشبكة. صدّر السجلات أو سوّها قبل المغادرة.',
      'leaveNetworkSuccess': 'تمت مغادرة الشبكة.',
      'leaveNetworkFailed': 'تعذر مغادرة الشبكة.',
      'reportSubtitleEn': 'Shared Housing Expense Report',
      'reportSubtitleAr': 'تقرير مصاريف السكن',
      'reportNetworkInfo': 'معلومات الشبكة',
      'reportMemberCount': 'عدد الأعضاء',
      'reportSettlementInstructions': 'تعليمات التسوية',
      'poweredByKaramix': 'بدعم من Karamix Labs',
      'copyLink': 'نسخ الرابط',
      'share': 'مشاركة',
      'inviteCopied': 'تم نسخ رابط الدعوة',
      'topPayer': 'الأكثر دفعا',
      'currentCycleTotal': 'الدورة الحالية',
      'averageExpense': 'متوسط المصروف',
      'expenseCount': 'عدد المصاريف',
      'monthlySpend': 'هذا الشهر',
      'activityTimeline': 'سجل النشاط',
      'noActivityYet': 'لا يوجد نشاط بعد.',
      'editAvatar': 'تعديل الصورة',
      'avatarPhotoPermissionDenied':
          'تم رفض الوصول إلى الصور. اسمح بالوصول إلى المعرض ثم حاول مرة أخرى.',
      'avatarPhotoMissing': 'لم يتم اختيار صورة. اختر صورة لتحديث الحساب.',
      'avatarPhotoPickFailed': 'تعذر فتح منتقي الصور. حاول مرة أخرى.',
      'avatarPhotoUploadFailed': 'تعذر رفع صورة الحساب. حاول مرة أخرى.',
      'avatarPhotoProfileUpdateFailed':
          'تم رفع الصورة، لكن تعذر تحديث الحساب. حاول مرة أخرى.',
      'avatarColor': 'لون الصورة',
      'save': 'حفظ',
      'pushExpenseAddedTitle': 'تمت إضافة مصروف جديد',
      'pushResetRequestedTitle': 'طلب بدء مصروف جديد',
      'pushCycleStartedTitle': 'تم بدء مصروف جديد',
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
  String get restoringSessionTitle => _text('restoringSessionTitle');
  String get restoringSessionMessage => _text('restoringSessionMessage');
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
  String get errorCloudRecordUnavailable =>
      _text('errorCloudRecordUnavailable');
  String get errorCreateNetworkFailed => _text('errorCreateNetworkFailed');
  String get errorSupabaseNotConfigured => _text('errorSupabaseNotConfigured');
  String get supabaseConfigurationMissingMessage =>
      _text('supabaseConfigurationMissingMessage');
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
  String get lastMemberLeaveWarning => _text('lastMemberLeaveWarning');
  String get cannotLeaveBeforeSettlement =>
      _text('cannotLeaveBeforeSettlement');
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
  String get avatarPhotoPermissionDenied =>
      _text('avatarPhotoPermissionDenied');
  String get avatarPhotoMissing => _text('avatarPhotoMissing');
  String get avatarPhotoPickFailed => _text('avatarPhotoPickFailed');
  String get avatarPhotoTooLarge => _text('avatarPhotoTooLarge');
  String get avatarPhotoUploadFailed => _text('avatarPhotoUploadFailed');
  String get avatarPhotoAuthRequired => _text('avatarPhotoAuthRequired');
  String get avatarPhotoStorageNotConfigured =>
      _text('avatarPhotoStorageNotConfigured');
  String get avatarPhotoStoragePermissionDenied =>
      _text('avatarPhotoStoragePermissionDenied');
  String get avatarPhotoProfileUpdateFailed =>
      _text('avatarPhotoProfileUpdateFailed');
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

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
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
