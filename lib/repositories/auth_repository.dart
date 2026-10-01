import '../core/api_client.dart';

/// Authenticated account as returned by the backend (single role: user).
class AuthAccount {
  final String id;
  final String email;
  final String role;
  final bool emailVerified;

  /// From `full_name` and `phone` returned by `/auth/me` (empty if legacy
  /// account without them).
  final String fullName;
  final String phone;

  const AuthAccount({
    required this.id,
    required this.email,
    required this.role,
    required this.emailVerified,
    this.fullName = '',
    this.phone = '',
  });

  factory AuthAccount.fromJson(Map<String, dynamic> json) => AuthAccount(
    id: (json['id'] ?? '').toString(),
    email: (json['email'] ?? '').toString(),
    role: (json['role'] ?? 'user').toString(),
    emailVerified: json['email_verified'] == true,
    fullName: (json['full_name'] ?? '').toString(),
    phone: (json['phone'] ?? '').toString(),
  );
}

class AuthTokens {
  final String access;
  final String refresh;

  const AuthTokens({required this.access, required this.refresh});

  factory AuthTokens.fromJson(Map<String, dynamic> json) => AuthTokens(
    access: (json['access_token'] ?? '').toString(),
    refresh: (json['refresh_token'] ?? '').toString(),
  );
}

class SignupResult {
  final AuthAccount account;
  final String? devOtp;

  const SignupResult({required this.account, this.devOtp});
}

/// Auth backend contract. HTTP binding below; tests use fakes.
abstract class AuthRepository {
  Future<SignupResult> signup({
    required String fullName,
    required String phone,
    required String email,
    required String password,
  });
  Future<AuthTokens> verifyOtp({required String email, required String code});
  Future<AuthTokens> login({required String email, required String password});
  Future<AuthTokens> refresh({required String refreshToken});
  Future<String?> requestReset({required String email});
  Future<String> verifyResetCode({required String email, required String code});
  Future<void> confirmReset({
    required String resetToken,
    required String newPassword,
  });
  Future<AuthAccount> me({required String accessToken});
}

const _prefix = '/api/v1/auth';

/// HTTP binding of [AuthRepository] against the gateway.
class HttpAuthRepository implements AuthRepository {
  HttpAuthRepository(this._client);

  final ApiClient _client;

  @override
  Future<SignupResult> signup({
    required String fullName,
    required String phone,
    required String email,
    required String password,
  }) async {
    final res = await _client.post(
      '$_prefix/signup',
      body: {
        'full_name': fullName,
        'phone': phone,
        'email': email,
        'password': password,
      },
    );
    return SignupResult(
      account: AuthAccount(
        id: (res['id'] ?? '').toString(),
        email: (res['email'] ?? email).toString(),
        role: (res['role'] ?? 'user').toString(),
        emailVerified: false,
      ),
      devOtp: res['dev_otp']?.toString(),
    );
  }

  @override
  Future<AuthTokens> verifyOtp({
    required String email,
    required String code,
  }) async {
    final res = await _client.post(
      '$_prefix/verify-otp',
      body: {'email': email, 'code': code},
    );
    return AuthTokens.fromJson(res);
  }

  @override
  Future<AuthTokens> login({
    required String email,
    required String password,
  }) async {
    final res = await _client.post(
      '$_prefix/login',
      body: {'email': email, 'password': password},
    );
    return AuthTokens.fromJson(res);
  }

  @override
  Future<AuthTokens> refresh({required String refreshToken}) async {
    final res = await _client.post(
      '$_prefix/refresh',
      body: {'refresh_token': refreshToken},
    );
    return AuthTokens.fromJson(res);
  }

  @override
  Future<String?> requestReset({required String email}) async {
    final res = await _client.post(
      '$_prefix/reset/request',
      body: {'email': email},
    );
    return res['dev_otp']?.toString();
  }

  @override
  Future<String> verifyResetCode({
    required String email,
    required String code,
  }) async {
    final res = await _client.post(
      '$_prefix/reset/verify',
      body: {'email': email, 'code': code},
    );
    return (res['reset_token'] ?? '').toString();
  }

  @override
  Future<void> confirmReset({
    required String resetToken,
    required String newPassword,
  }) async {
    await _client.post(
      '$_prefix/reset/confirm',
      body: {'reset_token': resetToken, 'new_password': newPassword},
    );
  }

  @override
  Future<AuthAccount> me({required String accessToken}) async {
    final res = await _client.getAuthed('$_prefix/me', accessToken);
    return AuthAccount.fromJson(res);
  }
}
