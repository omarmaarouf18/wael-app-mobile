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
  String get navMaterials => isArabic ? 'الكتب والمذكرات' : 'Books & Materials';
  String get navEbooks => isArabic ? 'الكتب الدراسية' : 'E-Books';
  String get navSettings => isArabic ? 'الإعدادات' : 'Settings';

  // Academic Structure & Hierarchy
  String get educationType => isArabic ? 'نوع الدراسة' : 'Education Type';
  String get academicYearLevel =>
      isArabic ? 'الفرقة / المستوى' : 'Academic Year / Level';
  String get subjectEntity => isArabic ? 'المادة الدراسية' : 'Subject';
  String get subjectContent => isArabic ? 'محتوى المادة' : 'Subject Content';
  String get eduLisence => isArabic ? 'ليسانس الحقوق' : 'LL.B. (Bachelor)';
  String get eduDiploma => isArabic ? 'دبلومة' : 'Diploma';
  String get eduVocational => isArabic ? 'تدريب مهني' : 'Vocational Training';
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
  String get booksAndMaterials =>
      isArabic ? 'الكتب والمذكرات' : 'Books & Materials';
  String get personalNotes => isArabic ? 'مذكراتي الشخصية' : 'Personal Notes';
  String get previewMaterial => isArabic ? 'معاينة الملف' : 'Preview Document';
  String get downloadMaterial => isArabic ? 'تحميل' : 'Download';
  String get emptyClasses => isArabic
      ? 'لا توجد حصص مجدولة حالياً في هذه المادة.'
      : 'No classes scheduled for this subject yet.';
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
  String get aboutInstructor =>
      isArabic ? 'عن المحاضر' : 'About the Instructor';
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
  String get rsvp => isArabic ? 'تأكيد الحضور' : 'RSVP';
  String get search => isArabic ? 'بحث...' : 'Search...';
  String get cancel => isArabic ? 'إلغاء' : 'Cancel';
  String get save => isArabic ? 'حفظ' : 'Save';
  String get submit => isArabic ? 'إرسال' : 'Submit';
  String get retry => isArabic ? 'إعادة المحاولة' : 'Retry';
  String get close => isArabic ? 'إغلاق' : 'Close';

  // Auth
  String get signIn => isArabic ? 'تسجيل الدخول' : 'Sign In';
  String get signUp => isArabic ? 'إنشاء حساب جديد' : 'Create Account';
  String get emailOrPhone =>
      isArabic ? 'البريد الإلكتروني أو رقم الهاتف' : 'Email or Phone Number';
  String get fullName => isArabic ? 'الاسم بالكامل' : 'Full Name';
  String get password => isArabic ? 'كلمة المرور' : 'Password';
  String get confirmPassword =>
      isArabic ? 'تأكيد كلمة المرور' : 'Confirm Password';
  String get rememberMe => isArabic ? 'تذكرني' : 'Remember me';
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
  String get verify => isArabic ? 'تأكيد' : 'Verify';
  String get resetPassword =>
      isArabic ? 'إعادة تعيين كلمة المرور' : 'Reset Password';
  String get sendCode => isArabic ? 'إرسال الرمز' : 'Send Code';
  String get newPassword => isArabic ? 'كلمة المرور الجديدة' : 'New Password';
  String get resetSentNote => isArabic
      ? 'إذا كان البريد مسجلاً، ستصلك رسالة برمز التأكيد.'
      : 'If the email is registered, a verification code was sent.';

  // Home Screen
  String get heroHeadline =>
      isArabic ? 'مستواك القادم\nيبدأ من هنا' : 'YOUR NEXT\nLEVEL STARTS\nHERE';
  String get heroSubheadline => isArabic
      ? 'تعلّم. استوعب. طبّق. لأن المعرفة قوة.'
      : 'Learn. Understand. Apply. Because knowledge is power.';
  String get crisisSeminar => isArabic
      ? 'ندوة إدارة الأزمات والخطاب السيادي'
      : 'Crisis Communication Seminar';
  String get todayGmt =>
      isArabic ? 'اليوم، 20:00 بتوقيت القاهرة' : 'Today, 20:00 GMT';

  // Courses Screen
  String get searchCoursesHint => isArabic
      ? 'ابحث في الدورات، المحاضرين، الموضوعات...'
      : 'Search courses, topics, instructors...';
  String get catAll => isArabic ? 'جميع الدورات' : 'All Courses';
  String get catLeadership => isArabic ? 'القيادة التنفيذية' : 'Leadership';
  String get catRhetoric => isArabic ? 'البلاغة والجدل' : 'Rhetoric';
  String get catBehavioral =>
      isArabic ? 'الاستراتيجية السلوكية' : 'Behavioral Strategy';
  String get catProtocol => isArabic ? 'البروتوكول الخاص' : 'Private Protocol';
  String get catAesthetics => isArabic ? 'الهيبة والحضور' : 'Aesthetics';
  String get featuredProgram =>
      isArabic ? 'برنامج أكاديمي متميز' : 'FEATURED ACADEMY PROGRAM';
  String get curriculumCatalog =>
      isArabic ? 'دليل البرامج الأكاديمية' : 'Curriculum Catalog';
  String get sortBy => isArabic ? 'ترتيب حسب' : 'Sort By';
  String get lessonsCount => isArabic ? 'درس' : 'Lessons';
  String get hoursCount => isArabic ? 'ساعة' : 'Hours';
  String get inProgress => isArabic ? 'قيد المتابعة' : 'In Progress';
  String get enrolled => isArabic ? 'مسجل' : 'Enrolled';
  String get readyToStart => isArabic ? 'جاهز للبدء' : 'Ready to Start';
  String get available => isArabic ? 'متاح للتسجيل' : 'Available';
  String get coreDiscipline => isArabic ? 'مادة أساسية' : 'Core Discipline';
  String get viewCourse => isArabic ? 'عرض الدورة' : 'View Course';

  // Course Details
  String get courseDossier =>
      isArabic ? 'ملف البرنامج الأكاديمي' : 'Course Dossier';
  String get masterClass => isArabic ? 'ماستر كلاس' : 'MASTER CLASS';
  String get addToNotes =>
      isArabic ? 'إضافة إلى الملاحظات' : 'Add to Study Notes';
  String get downloadSyllabus => isArabic ? 'تحميل المنهج' : 'Syllabus';
  String get curriculumStructure =>
      isArabic ? 'هيكل المنهج الدراسي' : 'Curriculum Structure';
  String get continueLesson =>
      isArabic ? 'متابعة الدرس ٠٧' : 'CONTINUE LESSON 07';
  String get enrollNow =>
      isArabic ? 'طلب الالتحاق بالدورة' : 'ENROL IN PROGRAM';
  String get currentTrack => isArabic ? 'المسار الحالي' : 'Current Track';
  String get completedBadge => isArabic ? 'مكتمل ✓' : 'Completed ✓';
  String get lockedBadge => isArabic ? '🔒 مقفل' : '🔒 Locked';

  // Lesson Screen
  String get lessonTitleFallback => isArabic
      ? 'قوة الصمت والتوقفات الاستراتيجية'
      : 'The Power of Pauses & Strategic Stillness';
  String get tabOverview => isArabic ? 'نظرة عامة' : 'Overview';
  String get tabKeyMaxims => isArabic ? 'القواعد الجوهرية' : 'Key Maxims';
  String get tabResources => isArabic ? 'المراجع والملفات' : 'Resources';
  String get recordObservation =>
      isArabic ? 'تدوين ملحوظة في المذكرات' : 'Record Observation in My Notes';
  String get prevLesson => isArabic ? 'السابق' : 'Prev';
  String get nextLesson => isArabic ? 'التالي' : 'Next';

  // E-Books & Notes
  String get studyDossier =>
      isArabic ? 'ملفات الدراسة والمذكرات' : 'Study Dossier';
  String get newNote => isArabic ? 'مذكرة جديدة' : 'New Note';
  String get allNotes => isArabic ? 'جميع المذكرات' : 'All Notes';
  String get byCourse => isArabic ? 'حسب الدورة' : 'By Course';
  String get pinnedNotes => isArabic ? 'المثبتة' : 'Pinned';
  String get drafts => isArabic ? 'المسودات' : 'Drafts';
  String get ebooksTitle => isArabic
      ? 'الكتب والمؤلفات الأكاديمية'
      : 'Academy Publications & E-Books';
  String get readBook => isArabic ? 'قراءة الكتاب' : 'Read Material';
  String get downloadOffline =>
      isArabic ? 'حفظ للاطلاع دون اتصال' : 'Save Offline';
  String get owned => isArabic ? 'متاح بالكامل' : 'Owned';
  String get requiresEnrolment =>
      isArabic ? 'يتطلب التسجيل' : 'Requires Enrolment';

  // Payment Screen
  String get paymentTitle =>
      isArabic ? 'تأكيد التسجيل والدفع' : 'Enrolment & Payment';
  String get selectAccessTier =>
      isArabic ? 'اختر باقة الالتحاق' : 'Select Access Tier';
  String get paymentMethod => isArabic ? 'طريقة السداد' : 'Payment Method';
  String get paymentInstructions =>
      isArabic ? 'تعليمات التحويل' : 'Payment Instructions';
  String get vodafoneCash => isArabic ? 'فودافون كاش' : 'Vodafone Cash';
  String get instaPay => isArabic ? 'إنستاباي (InstaPay)' : 'InstaPay';
  String get bankTransfer => isArabic ? 'تحويل بنكي' : 'Bank Transfer';
  String get transactionRef => isArabic
      ? 'رقم العملية / هاتف التحويل'
      : 'Transaction Reference / Sender Phone';
  String get uploadReceipt =>
      isArabic ? 'إرفاق إشعار التحويل' : 'Attach Transfer Receipt';
  String get receiptAttached =>
      isArabic ? 'تم إرفاق الإشعار بنجاح' : 'Receipt Attached';
  String get submitPaymentRequest =>
      isArabic ? 'إرسال طلب التحقق من الدفع' : 'SUBMIT PAYMENT REQUEST';
  String get statusPending => isArabic ? 'قيد المراجعة' : 'Pending Review';
  String get statusApproved =>
      isArabic ? 'تم التحقق بنجاح' : 'Approved & Verified';
  String get statusRejected =>
      isArabic ? 'مرفوض - يرجى مراجعة الإيصال' : 'Rejected';
  String get paymentInstructionBody => isArabic
      ? 'يرجى تحويل المبلغ المستحق إلى أحد الحسابات المعتمدة أدناه، ثم كتابة رقم العملية أو هاتف المُرسل للتحقق الفوري من قبل الإدارة الأكاديمية.'
      : 'Please transfer the required fee to one of the approved academy channels below, then enter your transaction reference or sender line for administrative verification.';

  // Settings Screen
  String get scholarDossier => isArabic ? 'ملف الدارس' : 'Scholar Dossier';
  String get editProfile => isArabic ? 'تعديل الملف الشخصي' : 'Edit Profile';
  String get accountSecurity =>
      isArabic ? 'الحساب والأمان' : 'Account & Security';
  String get biometricSignIn => isArabic
      ? 'تسجيل الدخول بالبصمة / Face ID'
      : 'Biometric Sign-In (Face ID)';
  String get passwordAnd2fa =>
      isArabic ? 'كلمة المرور والتحقق بخطوتين' : 'Password & Two-Factor Auth';
  String get emailCommunications =>
      isArabic ? 'البريد الإلكتروني والمراسلات' : 'Email & Communications';
  String get learningPreferences =>
      isArabic ? 'تفضيلات المشاهدة والتعلم' : 'Learning Preferences';
  String get videoQuality =>
      isArabic ? 'جودة عرض الفيديو' : 'Video Playback Quality';
  String get offlineDownloads =>
      isArabic ? 'التنزيلات غير المتصلة' : 'Offline Downloads';
  String get languageAndSubtitles =>
      isArabic ? 'اللغة والترجمة' : 'Language & Subtitles';
  String get notificationsSettings =>
      isArabic ? 'إشعارات الأكاديمية' : 'Notifications';
  String get liveEventReminders =>
      isArabic ? 'تنبيهات البث المباشر والندوات' : 'Live Event Reminders';
  String get curriculumUpdates =>
      isArabic ? 'تحديثات المناهج الدراسية' : 'Curriculum Updates';
  String get honorCodeAndTerms =>
      isArabic ? 'ميثاق الشرف الأكاديمي والشروط' : 'Academy Honor Code & Terms';
  String get privacyPolicy =>
      isArabic ? 'بروتوكول الخصوصية' : 'Privacy Protocol';
  String get signOut => isArabic
      ? 'تسجيل الخروج من أكاديمية المتر'
      : 'Sign Out of EL METR ACADEMY';
  String get technicalSupport =>
      isArabic ? 'الدعم الفني والأكاديمي' : 'Technical & Academic Support';

  // Notifications Screen
  String get dispatchesTitle =>
      isArabic ? 'بيانات وإشعارات الأكاديمية' : 'Academy Dispatches';
  String get markAllRead => isArabic ? 'تحديد الكل كمقروء' : 'Mark Read';
  String get noNotifications => isArabic
      ? 'لا توجد إشعارات جديدة حالياً.'
      : 'No new notifications at this time.';
  String get offlineDemoBanner => isArabic
      ? 'وضع المعاينة المباشرة (دون اتصال) • جميع البيانات محلية'
      : 'Live Interactive Demo Mode • Fully Offline';

  // Empty & Error States
  String get noCoursesFound => isArabic
      ? 'لم يتم العثور على دورات مطابقة للبحث.'
      : 'No courses match your query.';
  String get noNotesFound => isArabic
      ? 'لا توجد مذكرات في هذا التصنيف.'
      : 'No notes found in this category.';
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
