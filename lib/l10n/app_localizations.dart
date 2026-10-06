import 'package:flutter/material.dart';

/// Comprehensive Localization Dictionary for EL METR ACADEMY
/// Full bilingual support for English (LTR) and Arabic (RTL).
class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(const Locale('en'));
  }

  bool get isArabic => locale.languageCode == 'ar';

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  // Navigation
  String get navHome => isArabic ? 'الرئيسية' : 'Home';
  String get navCourses => isArabic ? 'الدورات' : 'Courses';
  String get navNotes => isArabic ? 'المذكرات' : 'My Notes';
  String get navSettings => isArabic ? 'الإعدادات' : 'Settings';

  // Academic Structure & Hierarchy
  String get educationType => isArabic ? 'نوع الدراسة' : 'Education Type';
  String get academicYearLevel =>
      isArabic ? 'الفرقة / المستوى' : 'Academic Year / Level';
  String get subjectEntity => isArabic ? 'المادة الدراسية' : 'Subject';
  String get subjectContent => isArabic ? 'محتوى المادة' : 'Subject Content';

  /// Tab label for a study type; other keys use [fallback] (the server title).
  String studyTypeLabel(String key, String fallback) => switch (key) {
    'bachelor' => isArabic ? 'الفرق' : 'Years',
    'diploma' => isArabic ? 'الدبلومات' : 'Diplomas',
    'vocational' => isArabic ? 'التدريب المهني' : 'Vocational Training',
    _ => fallback,
  };
  String get noDiplomasYet =>
      isArabic ? 'لا توجد دبلومات بعد' : 'No diplomas yet';
  String get noLevelsYet => isArabic ? 'لا توجد مستويات بعد' : 'No levels yet';
  String get noSubjectsYet => isArabic ? 'لا توجد مواد بعد' : 'No subjects yet';
  String get levelYear1 => isArabic ? 'الفرقة الأولى' : 'First Year';
  String get levelYear2 => isArabic ? 'الفرقة الثانية' : 'Second Year';
  String get levelYear3 => isArabic ? 'الفرقة الثالثة' : 'Third Year';
  String get levelYear4 => isArabic ? 'الفرقة الرابعة' : 'Fourth Year';

  // Subject Content Sections
  String get tabClasses => isArabic ? 'الحصص' : 'Classes';
  String get tabVideos => isArabic ? 'الفيديوهات' : 'Videos';
  String get tabBooks => isArabic ? 'الكتب' : 'Books';
  String get tabMaterials =>
      isArabic ? 'المذكرات والملفات التعليمية' : 'Academic Notes & PDFs';
  String get previewMaterial => isArabic ? 'معاينة الملف' : 'Preview Document';
  String get emptyVideos => isArabic
      ? 'لا توجد محاضرات مرئية مضافة حالياً.'
      : 'No video lectures added yet.';
  String get emptyBooks => isArabic
      ? 'لا توجد كتب دراسية مضافة حالياً.'
      : 'No accredited books added yet.';
  String get emptyMaterials => isArabic
      ? 'لا توجد مذكرات أو ملفات تعليمية مضافة حالياً.'
      : 'No academic handouts added yet.';

  // Instructor / Owner Section
  String get instructorSectionTitle =>
      isArabic ? 'المشرف والمحاضر العام' : 'ACADEMY DIRECTOR & INSTRUCTOR';
  String get readMore => isArabic ? 'اقرأ المزيد' : 'Read More';
  String get showLess => isArabic ? 'عرض أقل' : 'Show Less';

  // Branding
  String get appTitle => 'EL METR';
  String get appSubtitle => 'ACADEMY';
  String get academyMotto => isArabic
      ? 'الانضباط • الفكر • السيادة'
      : 'DISCIPLINE • INTELLECT • SOVEREIGNTY';
  String get admissionsNote => isArabic
      ? 'القبول قائم حصراً على الاستحقاق والكفاءة.'
      : 'Admissions are strictly merit-based.';

  // Common Actions
  String get exploreCourses => isArabic ? 'استكشف الدورات' : 'EXPLORE COURSES';
  String get continueLearning =>
      isArabic ? 'متابعة التعلم' : 'CONTINUE LEARNING';
  String get myCourses => isArabic ? 'دوراتي' : 'MY COURSES';
  String get upcoming => isArabic ? 'الفعاليات القادمة' : 'UPCOMING';
  String get viewAll => isArabic ? 'عرض الكل' : 'VIEW ALL';
  String get resume => isArabic ? 'استئناف' : 'Resume';
  String get search => isArabic ? 'بحث...' : 'Search...';
  String get cancel => isArabic ? 'إلغاء' : 'Cancel';
  String get save => isArabic ? 'حفظ' : 'Save';
  String get submit => isArabic ? 'إرسال' : 'Submit';
  String get retry => isArabic ? 'إعادة المحاولة' : 'Retry';
  String get close => isArabic ? 'إغلاق' : 'Close';
  String get back => isArabic ? 'رجوع' : 'Back';
  String get confirm => isArabic ? 'تأكيد' : 'Confirm';
  String get loading => isArabic ? 'جارٍ التحميل...' : 'Loading...';

  // Auth
  String get signIn => isArabic ? 'تسجيل الدخول' : 'Sign In';
  String get signUp => isArabic ? 'إنشاء حساب جديد' : 'Create Account';
  String get phoneNumber => isArabic ? 'رقم الهاتف المحمول' : 'Phone Number';
  String get email => isArabic ? 'البريد الإلكتروني' : 'Email';
  String get emailOrPhone =>
      isArabic ? 'البريد الإلكتروني أو رقم الهاتف' : 'Email or Phone Number';
  String get fullName => isArabic ? 'الاسم بالكامل' : 'Full Name';
  String get password => isArabic ? 'كلمة المرور' : 'Password';
  String get confirmPassword =>
      isArabic ? 'تأكيد كلمة المرور' : 'Confirm Password';
  String get forgotPassword =>
      isArabic ? 'نسيت كلمة المرور؟' : 'Forgot password?';
  String get dontHaveAccount =>
      isArabic ? 'ليس لديك حساب؟' : "Don't have an account?";
  String get alreadyHaveAccount =>
      isArabic ? 'لديك حساب بالفعل؟' : 'Already have an account?';
  String get createAccountPrompt => isArabic ? 'أنشئ حسابك' : 'Create account';
  String get signInPrompt => isArabic ? 'سجّل دخولك' : 'Sign In';
  String get agreeToTerms => isArabic
      ? 'أوافق على ميثاق الشرف الأكاديمي وشروط الخدمة'
      : 'I agree to the Academy Honor Code & Terms';
  String get verifyCode =>
      isArabic ? 'تأكيد البريد الإلكتروني' : 'Verify Email';
  String get verificationCode => isArabic ? 'رمز التأكيد' : 'Verification Code';
  String get verificationCodeRequired => isArabic
      ? 'يرجى إدخال رمز التأكيد كاملاً.'
      : 'Please enter the full code.';
  String get verify => isArabic ? 'تأكيد' : 'Verify';
  String get resendCode => isArabic ? 'إعادة إرسال الكود' : 'Resend code';
  String get resetPassword =>
      isArabic ? 'إعادة تعيين كلمة المرور' : 'Reset Password';
  String get sendCode => isArabic ? 'إرسال الرمز' : 'Send Code';
  String get newPassword => isArabic ? 'كلمة المرور الجديدة' : 'New Password';
  String get passwordRules => isArabic ? 'شروط كلمة المرور' : 'Password rules';
  String get passwordRuleLength =>
      isArabic ? '8 أحرف على الأقل' : 'At least 8 characters';
  String get passwordRuleBytes => isArabic
      ? 'بحد أقصى 72 بايت (الحروف العربية تُحسب بايتات متعددة)'
      : 'Max 72 bytes (Arabic letters count as multi-byte)';
  String get ruleMet => isArabic ? 'مستوفى' : 'Met';
  String get ruleUnmet => isArabic ? 'غير مستوفى' : 'Not met';
  String get showPassword => isArabic ? 'إظهار كلمة المرور' : 'Show password';
  String get hidePassword => isArabic ? 'إخفاء كلمة المرور' : 'Hide password';
  String get resetSentNote => isArabic
      ? 'إذا كان البريد مسجلاً، ستصلك رسالة برمز التأكيد.'
      : 'If the email is registered, a verification code was sent.';
  String get sessionReplaced => isArabic
      ? 'عفوًا، لقد تجاوزت الحد المسموح لاستخدام هذا الحساب'
      : "Sorry, this account's usage limit has been exceeded";
  String get signOutUnconfirmed => isArabic
      ? 'تعذر تأكيد تسجيل الخروج على الخادم.'
      : 'Could not confirm sign-out with the server.';

  // Home Screen
  String get heroHeadline =>
      isArabic ? 'مستواك القادم\nيبدأ من هنا' : 'YOUR NEXT\nLEVEL STARTS\nHERE';
  String get heroSubheadline => isArabic
      ? 'تعلّم. استوعب. طبّق. لأن المعرفة قوة.'
      : 'Learn. Understand. Apply. Because knowledge is power.';

  // Courses Screen
  String get searchCoursesHint => isArabic
      ? 'ابحث في الدورات، المحاضرين، الموضوعات...'
      : 'Search courses, topics, instructors...';
  String get curriculumCatalog =>
      isArabic ? 'دليل البرامج الأكاديمية' : 'Curriculum Catalog';
  String get readyToStart => isArabic ? 'جاهز للبدء' : 'Ready to Start';

  // Course Details
  String get courseDossier =>
      isArabic ? 'ملف البرنامج الأكاديمي' : 'Course Dossier';
  String get downloadSyllabus => isArabic ? 'تحميل المنهج' : 'Syllabus';

  // Lesson Screen

  // E-Books & Notes (coming soon until Phase 5; no payment wording)
  String get comingSoon => isArabic ? 'قريباً' : 'Coming soon';
  String get ebookComingSoon => isArabic
      ? 'المذكرات والمواد الدراسية ستظهر هنا قريباً.'
      : 'Study notes and materials will appear here soon.';

  // Settings Screen
  String get languageAndSubtitles =>
      isArabic ? 'اللغة والترجمة' : 'Language & Subtitles';
  String get signOut => isArabic
      ? 'تسجيل الخروج من أكاديمية المتر'
      : 'Sign Out of EL METR ACADEMY';
  String get signOutConfirmTitle => isArabic ? 'تسجيل الخروج؟' : 'Sign out?';
  String get signOutConfirmMessage => isArabic
      ? 'سيتم إنهاء جلستك على هذا الجهاز.'
      : 'Your session on this device will end.';

  // Notifications Screen
  String get dispatchesTitle =>
      isArabic ? 'بيانات وإشعارات الأكاديمية' : 'Academy Dispatches';
  String get markAllRead => isArabic ? 'تحديد الكل كمقروء' : 'Mark Read';
  String get noNotifications => isArabic
      ? 'لا توجد إشعارات جديدة حالياً.'
      : 'No new notifications at this time.';

  // Settings Screen
  String get languageAndPreferences =>
      isArabic ? 'اللغة والتفضيلات' : 'Language & Preferences';
  String languageSwitched(bool toArabic) => toArabic
      ? 'تم تحويل اللغة إلى العربية (RTL)'
      : 'Switched language to English (LTR)';
  String get allRightsReserved =>
      isArabic ? 'جميع الحقوق محفوظة © 2026' : 'All rights reserved © 2026';

  // Settings: my account (name, phone, email, password).
  String get myAccount => isArabic ? 'حسابي' : 'My account';
  String get nameLabel => isArabic ? 'الاسم' : 'Name';
  String get mobileNumber => isArabic ? 'رقم الموبايل' : 'Mobile number';
  String get currentPassword =>
      isArabic ? 'كلمة المرور الحالية' : 'Current password';
  String get changeOnceEvery30Days => isArabic
      ? 'يمكن التغيير مرة كل 30 يوم'
      : 'Can be changed once every 30 days';
  String get profileUpdated =>
      isArabic ? 'تم تحديث البيانات.' : 'Profile updated.';
  String get editNameTitle => isArabic ? 'تعديل الاسم' : 'Edit name';
  String get editPhoneTitle =>
      isArabic ? 'تعديل رقم الموبايل' : 'Edit mobile number';
  String get editEmailTitle =>
      isArabic ? 'تعديل البريد الإلكتروني' : 'Change email';
  String get newEmailLabel => isArabic ? 'البريد الجديد' : 'New email';
  String get changePasswordTitle =>
      isArabic ? 'تغيير كلمة السر' : 'Change password';
  String get passwordChanged =>
      isArabic ? 'تم تغيير كلمة السر.' : 'Password changed.';
  String get myDevices => isArabic ? 'أجهزتي' : 'My devices';
  String get thisDevice => isArabic ? 'هذا الجهاز' : 'This device';
  String get unknownDevice =>
      isArabic ? 'جهاز غير معروف' : 'Unknown device';
  String get signOutDevice =>
      isArabic ? 'تسجيل خروج من الجهاز ده' : 'Sign out of this device';
  String get signOutDeviceTitle =>
      isArabic ? 'إنهاء جلسة الجهاز؟' : "End this device's session?";
  String get signOutDeviceMessage => isArabic
      ? 'سيتم تسجيل الخروج من هذا الجهاز فورًا.'
      : 'This device will be signed out immediately.';
  String get deviceLimitNote => isArabic
      ? 'يمكن تسجيل الدخول من جهازين كحد أقصى في نفس الوقت.'
      : 'At most two devices may be signed in at once.';
  String get deviceSignedOut =>
      isArabic ? 'تم تسجيل الخروج من الجهاز.' : 'The device was signed out.';
  String get justNow => isArabic ? 'الآن' : 'Just now';
  String minutesAgo(int n) =>
      isArabic ? 'منذ $n دقيقة' : '$n minutes ago';
  String hoursAgo(int n) => isArabic ? 'منذ $n ساعة' : '$n hours ago';
  String daysAgo(int n) => isArabic ? 'منذ $n يوم' : '$n days ago';
  String get noOtherDevices => isArabic
      ? 'لا توجد أجهزة أخرى مسجلة الدخول.'
      : 'No other signed-in devices.';
  String get deleteAccount => isArabic ? 'حذف الحساب' : 'Delete account';
  String get deleteAccountWarning => isArabic
      ? 'سيتم حذف حسابك نهائيًا. ستفقد الوصول إلى المواد المفعّلة، ولا يمكن التراجع بعد انتهاء فترة السماح.'
      : 'Your account will be permanently deleted. You will lose access to activated subjects, and this cannot be undone after the grace period.';
  String get deleteAccountLoseAccess => isArabic
      ? 'هتفقد الوصول للمواد دي'
      : 'You will lose access to these subjects';
  String get deleteAccountGrace => isArabic
      ? 'بعد التأكيد تبدأ فترة سماح ٣٠ يومًا. لإلغاء الحذف يكفي تسجيل الدخول مرة أخرى خلالها.'
      : 'After confirming, a 30-day grace period starts. Signing in again during that time cancels the deletion.';
  String get deleteConfirmHint => isArabic
      ? 'اكتب كلمة "حذف" للتأكيد'
      : 'Type "حذف" to confirm';
  String deletionScheduled(String date) => isArabic
      ? 'تم طلب حذف الحساب. سيتم الحذف بتاريخ $date ما لم تسجل الدخول قبلها.'
      : 'Deletion requested. Your account will be deleted on $date unless you sign in before then.';
  String get backToLogin => isArabic ? 'العودة لتسجيل الدخول' : 'Back to sign in';
  String get deletionCancelledNotice => isArabic
      ? 'تم إلغاء حذف حسابك'
      : 'Your account deletion was cancelled.';
  String get emailCodeSent => isArabic
      ? 'تم إرسال رمز إلى بريدك الجديد. أدخله أدناه.'
      : 'A code was sent to your new email. Enter it below.';
  String get emailChangedMessage => isArabic
      ? 'تم تغيير البريد. سجل الدخول مجددًا.'
      : 'Email changed. Please sign in again.';
  String get sendCodeAction => isArabic ? 'إرسال الرمز' : 'Send code';

  // Settings: about this app (terms, privacy, version).
  String get aboutApp => isArabic ? 'عن التطبيق' : 'About';
  String get termsTitle => isArabic ? 'الشروط والأحكام' : 'Terms & Conditions';
  String get privacyTitle => isArabic ? 'سياسة الخصوصية' : 'Privacy Policy';
  String get appVersion => isArabic ? 'إصدار التطبيق' : 'App version';
  String get readTerms =>
      isArabic ? 'اقرأ الشروط والأحكام' : 'Read the Terms & Conditions';

  // Catalog (home, courses, subject detail)
  String get noOwnedCourses => isArabic
      ? 'لا توجد مواد مفعّلة لديك بعد.'
      : 'You have no active subjects yet.';
  String accessUntil(String date) =>
      isArabic ? 'متاحة حتى $date' : 'Access until $date';
  String subjectsCount(int n) => isArabic ? '$n مواد' : '$n Subjects';
  String get termFirst => isArabic ? 'الفصل الدراسي الأول' : 'First Term';
  String get termSecond => isArabic ? 'الفصل الدراسي الثاني' : 'Second Term';

  String get accessActive => isArabic ? 'الاشتراك فعّال' : 'Access active';
  String get requestPending =>
      isArabic ? 'الطلب قيد الانتظار' : 'Request pending';
  String get contactSupportToActivate => isArabic
      ? 'تواصل مع الدعم لتفعيل هذه المادة.'
      : 'Contact support to activate this subject.';
  String get sendingAccessRequest =>
      isArabic ? 'جارٍ إرسال طلبك…' : 'Sending your request…';
  String get copySupportLink =>
      isArabic ? 'نسخ رابط الدعم' : 'Copy support link';
  String get supportLinkCopied =>
      isArabic ? 'تم نسخ رابط الدعم' : 'Support link copied';
  String get openWhatsApp => isArabic ? 'تواصل على واتساب' : 'Chat on WhatsApp';

  /// Prefilled WhatsApp message for an access request: subject + student.
  String whatsappRequestText(String subject, String email) => isArabic
      ? 'مرحبًا، أرغب في تفعيل مادة "$subject" (البريد: $email).'
      : 'Hello, I would like to activate the subject "$subject" (email: $email).';
  String itemsCount(int n) => isArabic ? '$n محتوى' : '$n Items';
  String videoNumber(int n) => isArabic ? 'الفيديو $n' : 'Video $n';
  String get videoLocked => isArabic ? 'مقفل' : 'Locked';
  String get downloadsSoon => isArabic
      ? 'تحميل الملفات سيتاح في تحديث قادم.'
      : 'Downloads arrive in a later update.';
  String fileKind(String kind) => switch (kind) {
    'book' => isArabic ? 'كتاب' : 'Book',
    'note' => isArabic ? 'مذكرة' : 'Note',
    _ => kind,
  };

  // Video player
  String get playLabel => isArabic ? 'تشغيل' : 'Play';
  String get pauseLabel => isArabic ? 'إيقاف مؤقت' : 'Pause';
  String get rewind10 => isArabic ? 'رجوع ١٠ ثوانٍ' : 'Back 10 seconds';
  String get forward10 => isArabic ? 'تقدم ١٠ ثوانٍ' : 'Forward 10 seconds';
  String get enterFullscreen => isArabic ? 'ملء الشاشة' : 'Full screen';
  String get exitFullscreen =>
      isArabic ? 'إنهاء ملء الشاشة' : 'Exit full screen';
  String get replayLabel => isArabic ? 'إعادة التشغيل' : 'Replay';
  String get playbackSpeed => isArabic ? 'سرعة التشغيل' : 'Playback speed';
  String get nextLesson => isArabic ? 'الدرس التالي' : 'Next lesson';
  String nextLessonStartsIn(int seconds) => isArabic
      ? 'يبدأ الدرس التالي بعد $seconds ثانية.'
      : 'Next lesson starts in $seconds seconds.';
  String get subjectFinished =>
      isArabic ? 'انتهت دروس المادة' : 'No more lessons in this subject';
  String get playerStarting =>
      isArabic ? 'جارٍ تجهيز الفيديو...' : 'Preparing the video...';
  String get playerNoIdentity => isArabic
      ? 'بيانات حسابك غير مكتملة، لذلك لا يمكن تشغيل الفيديو. تواصل مع الدعم.'
      : 'Your profile is incomplete, so the video cannot start. Contact support.';
  String get playerNotSecure => isArabic
      ? 'تعذر حماية الشاشة على هذا الجهاز، لذلك لا يمكن تشغيل الفيديو.'
      : 'This device cannot protect the screen, so the video cannot play.';
  String get playerUnavailable => isArabic
      ? 'تعذر تشغيل الفيديو على هذا الجهاز.'
      : 'The video cannot be played on this device.';

  /// Label for a subject `term` key (`first`, `second`); other keys pass through.
  String termLabel(String term) => switch (term) {
    'first' => termFirst,
    'second' => termSecond,
    _ => term,
  };
  String get viewSubject => isArabic ? 'استعراض المحتوى' : 'View Subject';
  String get continueSubject => isArabic ? 'متابعة المادة' : 'Continue';

  // Empty & Error States
  String get offlineBanner => isArabic
      ? 'أنت غير متصل – بيانات آخر تحديث'
      : 'You are offline – showing last saved data.';
  String get noCoursesFound => isArabic
      ? 'لم يتم العثور على دورات مطابقة للبحث.'
      : 'No courses match your query.';
  String get errorLoading => isArabic
      ? 'حدث خطأ أثناء تحميل البيانات.'
      : 'An error occurred while loading data.';
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'ar'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) {
    return Future.value(AppLocalizations(locale));
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
