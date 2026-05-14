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
      'appTitle': 'Expense Network',
      'homeSubtitle':
          'Create or join a private group and settle shared costs clearly.',
      'createNetwork': 'Create Network',
      'joinNetwork': 'Join Network',
      'displayName': 'User display name',
      'networkName': 'Network name',
      'networkPassword': 'Network password',
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
    },
    'ar': {
      'appTitle': 'شبكة المصاريف',
      'homeSubtitle':
          'أنشئ مجموعة خاصة أو انضم إليها لتقسيم المصاريف وتسويتها بوضوح.',
      'createNetwork': 'إنشاء شبكة',
      'joinNetwork': 'الانضمام إلى شبكة',
      'displayName': 'اسم المستخدم الظاهر',
      'networkName': 'اسم الشبكة',
      'networkPassword': 'كلمة مرور الشبكة',
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

  String addingExpenseFor(String memberName) {
    return _text('addingExpenseFor').replaceAll('{member}', memberName);
  }

  String settlementPayment({
    required String fromMember,
    required String amount,
    required String toMember,
  }) {
    if (locale.languageCode == 'ar') {
      return '$fromMember $pays $amount $to $toMember';
    }
    return '$fromMember $pays $amount $to $toMember';
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
