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
      'appTitle': 'Shared Housing Expenses',
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
      'newExpenseNotification': '{actor} added {amount}',
      'localMode': 'Local mode',
      'cloudTestMode': 'Cloud test mode',
      'errorNoInternet':
          'Cloud mode needs an internet connection. Check your connection and try again.',
      'errorDuplicateNetwork': 'A network with this name already exists.',
      'errorDuplicateMember':
          'This member name is already used in the network.',
      'errorWrongNetworkPassword': 'Network name or password is incorrect.',
      'errorWrongPersonalPassword': 'Personal password is incorrect.',
      'errorSupabasePermission':
          'Cloud access was denied. Check Supabase RLS policies and test credentials.',
      'errorSupabaseNotConfigured':
          'Cloud test mode is not configured for this build.',
      'logout': 'Log out',
      'footerText':
          '© 2026 عبد الكريم حاج ياسين. جميع الحقوق محفوظة.',
    },
    'ar': {
      'appTitle': 'مصروف السكن الجماعي',
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
      'newExpenseNotification': 'أضاف {actor} {amount}',
      'localMode': 'الوضع المحلي',
      'cloudTestMode': 'وضع الاختبار السحابي',
      'errorNoInternet':
          'يحتاج الوضع السحابي إلى اتصال بالإنترنت. تحقق من الاتصال وحاول مرة أخرى.',
      'errorDuplicateNetwork': 'توجد شبكة بهذا الاسم بالفعل.',
      'errorDuplicateMember': 'اسم العضو مستخدم بالفعل في هذه الشبكة.',
      'errorWrongNetworkPassword': 'اسم الشبكة أو كلمة مرور الشبكة غير صحيحة.',
      'errorWrongPersonalPassword': 'كلمة مرور الحساب الشخصي غير صحيحة.',
      'errorSupabasePermission':
          'تم رفض الوصول السحابي. تحقق من سياسات Supabase RLS وبيانات الاختبار.',
      'errorSupabaseNotConfigured':
          'وضع الاختبار السحابي غير مهيأ في هذا الإصدار.',
      'logout': 'تسجيل الخروج',
      'footerText':
          '© 2026 عبد الكريم حاج ياسين. جميع الحقوق محفوظة.',
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
  String get localMode => _text('localMode');
  String get cloudTestMode => _text('cloudTestMode');
  String get errorNoInternet => _text('errorNoInternet');
  String get errorDuplicateNetwork => _text('errorDuplicateNetwork');
  String get errorDuplicateMember => _text('errorDuplicateMember');
  String get errorWrongNetworkPassword => _text('errorWrongNetworkPassword');
  String get errorWrongPersonalPassword => _text('errorWrongPersonalPassword');
  String get errorSupabasePermission => _text('errorSupabasePermission');
  String get errorSupabaseNotConfigured => _text('errorSupabaseNotConfigured');
  String get logout => _text('logout');
  String get footerText => _text('footerText');

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

  String newExpenseNotification({
    required String actor,
    required String amount,
  }) {
    return _text('newExpenseNotification')
        .replaceAll('{actor}', actor)
        .replaceAll('{amount}', amount);
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
