import 'dart:io' show SocketException;
import 'package:wael_app/core/api_client.dart' show ApiException;
import 'package:wael_app/repositories/auth_repository.dart';

/// Scripted fake backend for widget/unit tests.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.mode = 'ok', this.refreshMode = 'ok'});

  /// ok | wrong-password | wrong-otp | wrong-reset-code
  String mode;
  String refreshMode;
  int verifyOtpCalls = 0;
  int requestResetCalls = 0;
  int verifyResetCalls = 0;
  int confirmResetCalls = 0;
  String? lastOtpCode;

  @override
  Future<AuthTokens> login({
    required String email,
    required String password,
  }) async {
    if (mode == 'wrong-password') {
      throw ApiException(statusCode: 401, message: 'invalid credentials');
    }
    return const AuthTokens(access: 'access-1', refresh: 'refresh-1');
  }

  @override
  Future<AuthTokens> verifyOtp({
    required String email,
    required String code,
  }) async {
    verifyOtpCalls++;
    lastOtpCode = code;
    if (mode == 'wrong-otp') {
      throw ApiException(statusCode: 401, message: 'invalid code');
    }
    return const AuthTokens(access: 'access-1', refresh: 'refresh-1');
  }

  @override
  Future<SignupResult> signup({
    required String fullName,
    required String phone,
    required String email,
    required String password,
  }) async {
    return SignupResult(
      account: AuthAccount(
        id: 'id-1',
        email: email,
        role: 'user',
        emailVerified: false,
      ),
      devOtp: '123456',
    );
  }

  @override
  Future<AuthTokens> refresh({required String refreshToken}) async {
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
    return const AuthAccount(
      id: 'id-1',
      email: 'u@e.com',
      role: 'user',
      emailVerified: true,
    );
  }
}
