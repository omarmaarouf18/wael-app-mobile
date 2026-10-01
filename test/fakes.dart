import 'package:wael_app/core/api_client.dart' show ApiException;
import 'package:wael_app/repositories/auth_repository.dart';

/// Scripted fake backend for widget/unit tests.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.mode = 'ok'});

  /// ok | wrong-password
  String mode;

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
    return const AuthTokens(access: 'access-2', refresh: 'refresh-2');
  }

  @override
  Future<String?> requestReset({required String email}) async => '654321';

  @override
  Future<String> verifyResetCode({
    required String email,
    required String code,
  }) async => 'reset-token-1';

  @override
  Future<void> confirmReset({
    required String resetToken,
    required String newPassword,
  }) async {}

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
