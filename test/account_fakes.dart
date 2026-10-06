import 'package:wael_app/core/api_client.dart';
import 'package:wael_app/repositories/account_repository.dart';

/// Scriptable [AccountRepository] for settings tests.
class FakeAccountRepository implements AccountRepository {
  int profileCalls = 0;
  String? lastFullName;
  String? lastPhone;
  String? lastCurrentPassword;
  ProfileUpdate? profileResult;
  Object? profileError;

  int passwordCalls = 0;
  String? lastNewPassword;
  Object? passwordError;

  int emailChangeCalls = 0;
  String? lastNewEmail;
  Object? emailChangeError;

  int emailConfirmCalls = 0;
  String? lastCode;
  Object? emailConfirmError;

  final List<DeviceSession> sessionList = [];
  Object? sessionsError;
  final List<String> deletedSids = [];
  Object? deleteSessionError;

  Object? deletionError;
  String deletionDate = '2026-11-05';
  int deletionCalls = 0;
  String? lastDeletionPassword;

  @override
  Future<ProfileUpdate> updateProfile({
    String? fullName,
    String? phone,
    required String currentPassword,
  }) async {
    profileCalls++;
    lastFullName = fullName;
    lastPhone = phone;
    lastCurrentPassword = currentPassword;
    if (profileError != null) throw profileError!;
    return profileResult ??
        ProfileUpdate(fullName: fullName ?? '', phone: phone ?? '');
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    passwordCalls++;
    lastCurrentPassword = currentPassword;
    lastNewPassword = newPassword;
    if (passwordError != null) throw passwordError!;
  }

  @override
  Future<void> requestEmailChange({
    required String newEmail,
    required String currentPassword,
  }) async {
    emailChangeCalls++;
    lastNewEmail = newEmail;
    lastCurrentPassword = currentPassword;
    if (emailChangeError != null) throw emailChangeError!;
  }

  @override
  Future<void> confirmEmailChange({required String code}) async {
    emailConfirmCalls++;
    lastCode = code;
    if (emailConfirmError != null) throw emailConfirmError!;
  }

  @override
  Future<List<DeviceSession>> sessions() async {
    if (sessionsError != null) throw sessionsError!;
    return List.of(sessionList);
  }

  @override
  Future<void> deleteSession(String sid) async {
    if (deleteSessionError != null) throw deleteSessionError!;
    deletedSids.add(sid);
  }

  @override
  Future<String> requestDeletion({
    required String currentPassword,
    String confirm = 'حذف',
  }) async {
    deletionCalls++;
    lastDeletionPassword = currentPassword;
    if (deletionError != null) throw deletionError!;
    if (confirm != 'حذف') throw ArgumentError('confirm');
    return deletionDate;
  }
}

/// A 429 change_too_soon failure with a Retry-After, like the backend.
ApiException changeTooSoon({int retryAfter = 3600}) => ApiException(
  statusCode: 429,
  message: 'change too soon, retry later',
  code: 'change_too_soon',
  retryAfterSeconds: retryAfter,
);
