/// Standardized Error Messages supporting localized resolution
class ErrorMessages {
  ErrorMessages._();

  static String networkError(bool isArabic) => isArabic
      ? 'تعذر الاتصال بالخادم. التطبيق يعمل حالياً في وضع العرض غير المتصل.'
      : 'Unable to reach the server. Application is currently running in offline demo mode.';

  static String invalidCredentials(bool isArabic) => isArabic
      ? 'بيانات الاعتماد غير صحيحة. يرجى التحقق والمحاولة مرة أخرى.'
      : 'Invalid credentials. Please verify your details and try again.';

  static String emptyField(bool isArabic) =>
      isArabic ? 'هذا الحقل مطلوب.' : 'This field is required.';

  static String invalidEmail(bool isArabic) => isArabic
      ? 'يرجى إدخال بريد إلكتروني صالح.'
      : 'Please enter a valid email address.';

  static String passwordTooShort(bool isArabic) => isArabic
      ? 'كلمة المرور يجب ألا تقل عن 6 أحرف.'
      : 'Password must be at least 6 characters.';

  static String passwordMismatch(bool isArabic) =>
      isArabic ? 'كلمتا المرور غير متطابقتين.' : 'Passwords do not match.';

  static String paymentProofRequired(bool isArabic) => isArabic
      ? 'يرجى إرفاق إيصال التحويل أو رقم العملية لتأكيد الطلب.'
      : 'Please provide the transaction reference or receipt to verify payment.';

  static String courseLocked(bool isArabic) => isArabic
      ? 'هذا المحتوى مقيد. يرجى إتمام إجراءات التسجيل والاشتراك للوصول.'
      : 'This content is restricted. Complete enrolment to gain access.';
}
