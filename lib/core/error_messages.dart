import '../models/academy_catalog.dart';
import 'api_client.dart';

/// Standardized Error Messages supporting localized resolution
class ErrorMessages {
  ErrorMessages._();

  static String networkError(bool isArabic) => isArabic
      ? 'تعذر الاتصال بالخادم. يرجى التحقق من اتصالك بالإنترنت والمحاولة مجدداً.'
      : 'Unable to reach the server. Please check your connection and try again.';

  static String invalidCredentials(bool isArabic) => isArabic
      ? 'بيانات الاعتماد غير صحيحة. يرجى التحقق والمحاولة مرة أخرى.'
      : 'Invalid credentials. Please verify your details and try again.';

  static String emptyField(bool isArabic) =>
      isArabic ? 'هذا الحقل مطلوب.' : 'This field is required.';

  static String allFieldsRequired(bool isArabic) => isArabic
      ? 'يرجى إكمال جميع الحقول المطلوبة.'
      : 'Please complete all required fields.';

  static String invalidEmail(bool isArabic) => isArabic
      ? 'يرجى إدخال بريد إلكتروني صالح.'
      : 'Please enter a valid email address.';

  static String passwordTooShort(bool isArabic) => isArabic
      ? 'كلمة المرور يجب ألا تقل عن 6 أحرف.'
      : 'Password must be at least 6 characters.';

  static String passwordMinLength(bool isArabic, int minLength) => isArabic
      ? 'كلمة المرور يجب ألا تقل عن $minLength أحرف.'
      : 'Password must be at least $minLength characters.';

  static String passwordMismatch(bool isArabic) =>
      isArabic ? 'كلمتا المرور غير متطابقتين.' : 'Passwords do not match.';

  static String rateLimited(bool isArabic) => isArabic
      ? 'محاولات كثيرة جداً. يرجى الانتظار والمحاولة لاحقاً.'
      : 'Too many attempts. Please wait and try again.';

  static String requestFailed(bool isArabic) => isArabic
      ? 'فشل الطلب. يرجى المحاولة مرة أخرى.'
      : 'Request failed. Please try again.';

  static String invalidOrExpiredCode(bool isArabic) => isArabic
      ? 'رمز التحقق غير صالح أو منتهي الصلاحية.'
      : 'Invalid or expired verification code.';

  static String emailNotVerified(bool isArabic) => isArabic
      ? 'البريد الإلكتروني غير مؤكد. يرجى تأكيد حسابك.'
      : 'Email address is not verified. Please verify your account.';

  static String duplicateEmail(bool isArabic) => isArabic
      ? 'يوجد حساب مسجل بهذا البريد الإلكتروني مسبقاً.'
      : 'An account with this email already exists.';

  static String agreeToTermsRequired(bool isArabic) => isArabic
      ? 'يجب الموافقة على ميثاق الشرف الأكاديمي للمتابعة.'
      : 'You must agree to the Academy Honor Code to proceed.';

  static String notificationLoadFailed(bool isArabic) => isArabic
      ? 'تعذر تحميل الإشعارات. يرجى المحاولة لاحقاً.'
      : 'Unable to load notifications. Please try again later.';

  static String courseLocked(bool isArabic) => isArabic
      ? 'هذا المحتوى مقيد. يرجى إتمام إجراءات التسجيل والاشتراك للوصول.'
      : 'This content is restricted. Complete enrolment to gain access.';

  static String catalogLoadFailed(bool isArabic) => isArabic
      ? 'تعذر تحميل المحتوى الدراسي. يرجى المحاولة مرة أخرى.'
      : 'Unable to load the course catalog. Please try again.';

  static String subjectNotFound(bool isArabic) =>
      isArabic ? 'هذه المادة غير متاحة.' : 'This subject is not available.';

  static String serviceUnavailable(bool isArabic) => isArabic
      ? 'الخدمة غير متاحة مؤقتاً. يرجى المحاولة بعد قليل.'
      : 'The service is temporarily unavailable. Please try again shortly.';

  static String accessRequestUnavailable(bool isArabic) => isArabic
      ? 'لا يمكن طلب هذه المادة حالياً.'
      : 'This subject can\'t be requested right now.';

  static String tryAgainLater(bool isArabic) =>
      isArabic ? 'يرجى المحاولة لاحقاً.' : 'Please try again later.';

  /// Message for a failed access request. 409 is the server's generic
  /// refusal (already owned, or the subject's access date has passed), so it
  /// is worded without guessing which.
  static String forAccessRequest(Object e, {bool isArabic = false}) {
    if (e is ApiException) {
      if (e.isRateLimited) return tryAgainLater(isArabic);
      if (e.statusCode == 404) return subjectNotFound(isArabic);
      if (e.statusCode == 409) return accessRequestUnavailable(isArabic);
      if (e.statusCode == 503) return serviceUnavailable(isArabic);
      return requestFailed(isArabic);
    }
    if (e is AcademyParseException) return requestFailed(isArabic);
    return networkError(isArabic);
  }

  /// Message for a failed catalog request. Unlike [forApiError] it never
  /// reads a 401 as bad credentials or a 403 as an unverified email.
  static String forCatalog(Object e, {bool isArabic = false}) {
    if (e is ApiException) {
      if (e.isRateLimited) return rateLimited(isArabic);
      if (e.statusCode == 404) return subjectNotFound(isArabic);
      if (e.statusCode == 503) return serviceUnavailable(isArabic);
      return catalogLoadFailed(isArabic);
    }
    if (e is AcademyParseException) return catalogLoadFailed(isArabic);
    return networkError(isArabic);
  }

  /// Resolves an [ApiException] into a sanitized, user-facing error message.
  /// Never displays raw exception text or internal stack traces.
  static String forApiError(ApiException e, {bool isArabic = false}) {
    if (e.isRateLimited || e.code == 'locked_out') {
      return rateLimited(isArabic);
    }
    if (e.code == 'duplicate_email') {
      return duplicateEmail(isArabic);
    }
    if (e.code == 'invalid_token') {
      return invalidOrExpiredCode(isArabic);
    }
    if (e.statusCode == 401) {
      return invalidCredentials(isArabic);
    }
    if (e.statusCode == 403) {
      return emailNotVerified(isArabic);
    }
    final msg = e.message.toLowerCase();
    if (msg.contains('invalid credentials') || msg.contains('wrong password')) {
      return invalidCredentials(isArabic);
    }
    if (msg.contains('too many') || msg.contains('locked')) {
      return rateLimited(isArabic);
    }
    if (msg.contains('already exists') || msg.contains('already registered')) {
      return duplicateEmail(isArabic);
    }
    if (msg.contains('invalid or expired') || msg.contains('expired code')) {
      return invalidOrExpiredCode(isArabic);
    }
    return requestFailed(isArabic);
  }

  /// Resolves any generic exception or error into a sanitized message.
  /// Guaranteed to never expose raw exception strings or stack traces.
  static String forException(Object e, {bool isArabic = false}) {
    if (e is ApiException) {
      return forApiError(e, isArabic: isArabic);
    }
    return networkError(isArabic);
  }
}
