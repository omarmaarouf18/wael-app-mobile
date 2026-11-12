import 'dart:convert' show utf8;

import 'error_messages.dart';

/// Inline per-field validators for the auth forms (login, signup, forgot
/// password). Field errors render under the field; the banner is kept for
/// server errors only.
class FieldValidators {
  FieldValidators._();

  /// Shortest password the backend accepts.
  static const minPasswordLength = 8;

  /// Longest password the backend accepts, in UTF-8 bytes (bcrypt limit).
  /// Arabic counts as multi-byte; measure with [utf8], never [String.length].
  static const maxPasswordBytes = 72;

  static String? required(String? value, {required bool isArabic}) {
    if (value == null || value.trim().isEmpty) {
      return ErrorMessages.emptyField(isArabic);
    }
    return null;
  }

  static String? email(String? value, {required bool isArabic}) {
    if (value == null || value.trim().isEmpty) {
      return ErrorMessages.emptyField(isArabic);
    }
    final v = value.trim();
    final at = v.indexOf('@');
    if (at <= 0 || at != v.lastIndexOf('@') || at == v.length - 1) {
      return ErrorMessages.invalidEmail(isArabic);
    }
    if (!v.substring(at).contains('.')) {
      return ErrorMessages.invalidEmail(isArabic);
    }
    return null;
  }

  /// Optional phone (owner amendment 2026-11-03, App Store 5.1.1(v)): empty
  /// passes; a typed number must look like a phone (an optional leading +,
  /// then 8 to 15 digits, spaces and dashes allowed). The server still
  /// normalizes and validates it.
  static String? optionalPhone(String? value, {required bool isArabic}) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    final body = v.startsWith('+') ? v.substring(1) : v;
    if (!RegExp(r'^[0-9 \-]+$').hasMatch(body)) {
      return ErrorMessages.invalidPhone(isArabic);
    }
    final digits = body.replaceAll(RegExp(r'[ \-]'), '').length;
    if (digits < 8 || digits > 15) return ErrorMessages.invalidPhone(isArabic);
    return null;
  }

  /// Required phone (Android signup, owner amendment 2026-11-12): empty is
  /// refused; a typed number follows [optionalPhone].
  static String? requiredPhone(String? value, {required bool isArabic}) {
    if ((value?.trim() ?? '').isEmpty) {
      return ErrorMessages.emptyField(isArabic);
    }
    return optionalPhone(value, isArabic: isArabic);
  }

  /// Login password: required only. The server decides validity; the client
  /// must not block short input with a length rule here.
  static String? loginPassword(String? value, {required bool isArabic}) {
    if (value == null || value.isEmpty) {
      return ErrorMessages.emptyField(isArabic);
    }
    return null;
  }

  /// New password (signup, reset): 8+ characters and the 72-byte limit.
  static String? newPassword(String? value, {required bool isArabic}) {
    if (value == null || value.isEmpty) {
      return ErrorMessages.emptyField(isArabic);
    }
    if (value.length < minPasswordLength) {
      return ErrorMessages.passwordMinLength(isArabic, minPasswordLength);
    }
    if (utf8.encode(value).length > maxPasswordBytes) {
      return ErrorMessages.passwordTooLong(isArabic);
    }
    return null;
  }

  static String? confirmPassword(
    String? value,
    String original, {
    required bool isArabic,
  }) {
    if (value == null || value.isEmpty) {
      return ErrorMessages.emptyField(isArabic);
    }
    if (value != original) {
      return ErrorMessages.passwordMismatch(isArabic);
    }
    return null;
  }
}
