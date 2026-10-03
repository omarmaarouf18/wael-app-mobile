import 'dart:io' show SocketException;
import 'package:wael_app/core/api_client.dart' show ApiException;
import 'package:wael_app/repositories/auth_repository.dart';

/// Scripted fake backend for widget/unit tests.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.mode = 'ok', this.refreshMode = 'ok'});

  /// ok | wrong-password | unverified | wrong-otp | wrong-reset-code | signup-conflict
  String mode;
  String refreshMode;
  String logoutMode = 'ok';

  /// Identity `me()` returns; empty means the backend sent none (today).
  String meFullName = '';
  String mePhone = '';
  int signupCalls = 0;
  String? lastSignupEmail;
  int loginCalls = 0;
  String? lastLoginEmail;
  String? lastLoginDeviceId;
  String? lastLoginDeviceLabel;
  int verifyOtpCalls = 0;
  String? lastVerifyOtpDeviceId;
  String? lastVerifyOtpDeviceLabel;
  String? lastVerifyOtpPendingId;
  int logoutCalls = 0;
  String? lastLogoutToken;
  int requestResetCalls = 0;
  int verifyResetCalls = 0;
  int confirmResetCalls = 0;
  String? lastOtpCode;
  int resendSignupCalls = 0;
  String? lastResendEmail;

  @override
  Future<AuthTokens> login({
    required String email,
    required String password,
    required String deviceId,
    String? deviceLabel,
  }) async {
    loginCalls++;
    lastLoginEmail = email;
    lastLoginDeviceId = deviceId;
    lastLoginDeviceLabel = deviceLabel;
    if (mode == 'wrong-password') {
      throw ApiException(statusCode: 401, message: 'invalid credentials');
    }
    if (mode == 'unverified') {
      throw ApiException(statusCode: 403, message: 'email not verified');
    }
    return const AuthTokens(access: 'access-1', refresh: 'refresh-1');
  }

  @override
  Future<AuthTokens> verifyOtp({
    required String email,
    required String code,
    required String deviceId,
    String? deviceLabel,
    String? pendingId,
  }) async {
    verifyOtpCalls++;
    lastOtpCode = code;
    lastVerifyOtpDeviceId = deviceId;
    lastVerifyOtpDeviceLabel = deviceLabel;
    lastVerifyOtpPendingId = pendingId;
    if (mode == 'wrong-otp') {
      throw ApiException(statusCode: 401, message: 'invalid code');
    }
    return const AuthTokens(access: 'access-1', refresh: 'refresh-1');
  }

  @override
  Future<void> logout({required String accessToken}) async {
    logoutCalls++;
    lastLogoutToken = accessToken;
    if (logoutMode == '401') {
      throw ApiException(statusCode: 401, message: 'unauthorized');
    }
    if (logoutMode == '503') {
      throw ApiException(statusCode: 503, message: 'service unavailable');
    }
    if (logoutMode == 'network') {
      throw const SocketException('network unreachable');
    }
  }

  @override
  Future<SignupResult> signup({
    required String fullName,
    required String phone,
    required String email,
    required String password,
  }) async {
    signupCalls++;
    lastSignupEmail = email;
    if (mode == 'signup-conflict') {
      throw ApiException(statusCode: 409, message: 'email already registered');
    }
    return SignupResult(
      account: AuthAccount(
        id: 'id-1',
        email: email,
        role: 'user',
        emailVerified: false,
      ),
      devOtp: '123456',
      pendingId: 'pending-test-id',
    );
  }

  @override
  Future<AuthTokens> refresh({required String refreshToken}) async {
    if (refreshMode == 'session_replaced') {
      throw ApiException(
        statusCode: 401,
        message: "Sorry, this account's usage limit has been exceeded",
        code: 'session_replaced',
      );
    }
    if (refreshMode == 'session_replaced_ar') {
      throw ApiException(
        statusCode: 401,
        message: "عفوًا، لقد تجاوزت الحد المسموح لاستخدام هذا الحساب",
        code: 'session_replaced',
      );
    }
    if (refreshMode == '401') {
      throw ApiException(statusCode: 401, message: 'invalid refresh token');
    }
    if (refreshMode == '403') {
      throw ApiException(statusCode: 403, message: 'forbidden');
    }
    if (refreshMode == '500') {
      throw ApiException(statusCode: 500, message: 'internal server error');
    }
    if (refreshMode == '503') {
      throw ApiException(statusCode: 503, message: 'service unavailable');
    }
    if (refreshMode == 'network') {
      throw const SocketException('network unreachable');
    }
    return const AuthTokens(access: 'access-2', refresh: 'refresh-2');
  }

  @override
  Future<String?> requestReset({required String email}) async {
    requestResetCalls++;
    return '654321';
  }

  @override
  Future<String> verifyResetCode({
    required String email,
    required String code,
  }) async {
    verifyResetCalls++;
    if (mode == 'wrong-reset-code') {
      throw ApiException(statusCode: 401, message: 'invalid code');
    }
    return 'reset-token-1';
  }

  @override
  Future<void> confirmReset({
    required String resetToken,
    required String newPassword,
  }) async {
    confirmResetCalls++;
  }

  @override
  Future<AuthAccount> me({required String accessToken}) async {
    return AuthAccount(
      id: 'id-1',
      email: 'u@e.com',
      role: 'user',
      emailVerified: true,
      fullName: meFullName,
      phone: mePhone,
    );
  }

  @override
  Future<String?> resendSignup({required String email}) async {
    resendSignupCalls++;
    lastResendEmail = email;
    return '123456';
  }
}
