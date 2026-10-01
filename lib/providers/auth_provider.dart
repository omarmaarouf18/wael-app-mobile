import 'dart:async';
import 'package:flutter/foundation.dart'
    show ChangeNotifier, kDebugMode, visibleForTesting;
import '../core/api_client.dart';
import '../core/app_config.dart';
import '../core/error_messages.dart';
import '../core/secure_store.dart';
import '../models/user_profile.dart';
import '../repositories/auth_repository.dart';

/// Session states for the app start gate and auth screens.
enum AuthStatus { unknown, authenticated, unauthenticated, needsVerification }

class AuthProvider extends ChangeNotifier {
  AuthProvider({
    AuthRepository? repository,
    TokenStore? tokenStore,
    ApiClient? api,
  }) : _tokens = tokenStore ?? SecureTokenStore(),
       _api =
           api ??
           ApiClient(
             baseUrl: AppConfig.baseUrl,
             allowSelfSigned: AppConfig.allowSelfSigned,
           ) {
    _repo = repository ?? HttpAuthRepository(_plainApi());
    _apiWithCallbacks = ApiClient(
      baseUrl: AppConfig.baseUrl,
      allowSelfSigned: AppConfig.allowSelfSigned,
      accessTokenReader: _tokens.readAccessToken,
      refreshTokens: _doRefresh,
    );
  }

  ApiClient _plainApi() => ApiClient(
    baseUrl: AppConfig.baseUrl,
    allowSelfSigned: AppConfig.allowSelfSigned,
  );

  late final AuthRepository _repo;
  final TokenStore _tokens;
  final ApiClient _api;
  late final ApiClient _apiWithCallbacks;

  ApiClient get authedApi => _apiWithCallbacks;

  /// Current stored access token for stream setup (null when logged out).
  Future<String?> authedTokenForStream() => _tokens.readAccessToken();

  AuthStatus _status = AuthStatus.unknown;
  bool _isLoading = false;
  String? _errorMessage;
  bool _rememberMe = true;
  AuthAccount? _account;
  String? _pendingVerificationEmail;

  /// Last dev OTP returned by the backend in local mode. Set in debug
  /// builds only; always null in release builds.
  String? _lastDevOtp;

  static const _blankUser = UserProfile(
    id: 'pending',
    dossierId: '',
    fullName: '',
    email: '',
    phone: '',
    specializationTrack: '',
    bio: '',
  );

  UserProfile _currentUser = _blankUser;

  AuthStatus get status => _status;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get rememberMe => _rememberMe;
  UserProfile get currentUser => _currentUser;
  AuthAccount? get account => _account;
  String? get pendingVerificationEmail => _pendingVerificationEmail;
  String? get lastDevOtp => kDebugMode ? _lastDevOtp : null;

  void setRememberMe(bool value) {
    _rememberMe = value;
    notifyListeners();
  }

  void _begin() {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
  }

  void _fail(Object e) {
    _isLoading = false;
    _errorMessage = _messageFor(e);
    notifyListeners();
  }

  static String _messageFor(Object e) {
    return ErrorMessages.forException(e);
  }

  Future<void> _storeSession(AuthAccount account, AuthTokens tokens) async {
    await _tokens.writeTokens(access: tokens.access, refresh: tokens.refresh);
    _account = account;
    _currentUser = _withAccount(_currentUser, account);
    _status = AuthStatus.authenticated;
    _pendingVerificationEmail = null;
    _isLoading = false;
    notifyListeners();
  }

  /// Copies the account's identity into the profile; name and phone only
  /// when the server sent them, so a value typed at signup is not erased.
  static UserProfile _withAccount(UserProfile user, AuthAccount account) {
    return user.copyWith(
      id: account.id,
      email: account.email,
      fullName: account.fullName.trim().isNotEmpty
          ? account.fullName.trim()
          : null,
      phone: account.phone.trim().isNotEmpty ? account.phone.trim() : null,
    );
  }

  /// Identity text for the moving video watermark: full name and phone when
  /// known, otherwise the email, otherwise null (the player then refuses to
  /// start, because a watermark must always identify the student).
  String? get watermarkText {
    final parts = [
      _currentUser.fullName.trim(),
      _currentUser.phone.trim(),
    ].where((s) => s.isNotEmpty).toList();
    if (parts.isNotEmpty) return parts.join(' · ');
    final email = (_account?.email ?? _currentUser.email).trim();
    return email.isEmpty ? null : email;
  }

  @visibleForTesting
  Future<bool> doRefresh() => _doRefresh();

  Future<bool> _doRefresh() async {
    final refresh = await _tokens.readRefreshToken();
    if (refresh == null || refresh.isEmpty) {
      await _logoutLocal();
      return false;
    }
    try {
      final tokens = await _repo.refresh(refreshToken: refresh);
      await _tokens.writeTokens(access: tokens.access, refresh: tokens.refresh);
      return true;
    } on ApiException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403) {
        await _logoutLocal();
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Splash gate: restores the session when a stored token still validates.
  Future<void> tryRestore() async {
    final access = await _tokens.readAccessToken();
    if (access == null || access.isEmpty) {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }
    try {
      final account = await _repo.me(accessToken: access);
      _account = account;
      _currentUser = _withAccount(_currentUser, account);
      _status = AuthStatus.authenticated;
    } catch (_) {
      await _tokens.clear();
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<bool> login(String identifier, String password) async {
    _begin();
    final email = identifier.trim();
    if (email.isEmpty || password.isEmpty) {
      _isLoading = false;
      _errorMessage = ErrorMessages.allFieldsRequired(false);
      notifyListeners();
      return false;
    }
    try {
      final tokens = await _repo.login(email: email, password: password);
      final account = await _repo.me(accessToken: tokens.access);
      await _storeSession(account, tokens);
      return true;
    } on ApiException catch (e) {
      if (e.statusCode == 403) {
        _isLoading = false;
        _status = AuthStatus.needsVerification;
        _pendingVerificationEmail = email;
        notifyListeners();
        return false;
      }
      _fail(e);
      return false;
    } catch (e) {
      _fail(e);
      return false;
    }
  }

  Future<bool> signup({
    required String fullName,
    required String phone,
    required String email,
    required String password,
  }) async {
    _begin();
    try {
      final result = await _repo.signup(
        fullName: fullName.trim(),
        phone: phone.trim(),
        email: email.trim(),
        password: password,
      );
      _lastDevOtp = kDebugMode ? result.devOtp : null;
      // The name and phone typed here are the only copy until the backend's
      // /auth/me returns them.
      _currentUser = _currentUser.copyWith(
        fullName: fullName.trim(),
        phone: phone.trim(),
      );
      _isLoading = false;
      _status = AuthStatus.needsVerification;
      _pendingVerificationEmail = email.trim();
      notifyListeners();
      return true;
    } catch (e) {
      _fail(e);
      return false;
    }
  }

  Future<bool> verifyOtp({required String email, required String code}) async {
    _begin();
    try {
      final tokens = await _repo.verifyOtp(
        email: email.trim(),
        code: code.trim(),
      );
      final account = await _repo.me(accessToken: tokens.access);
      await _storeSession(account, tokens);
      return true;
    } catch (e) {
      _fail(e);
      return false;
    }
  }

  Future<String?> requestReset(String email) async {
    _begin();
    try {
      final devOtp = await _repo.requestReset(email: email.trim());
      _lastDevOtp = kDebugMode ? devOtp : null;
      _isLoading = false;
      notifyListeners();
      return _lastDevOtp;
    } catch (e) {
      _fail(e);
      return null;
    }
  }

  Future<String?> verifyResetCode({
    required String email,
    required String code,
  }) async {
    _begin();
    try {
      final token = await _repo.verifyResetCode(
        email: email.trim(),
        code: code.trim(),
      );
      _isLoading = false;
      notifyListeners();
      return token;
    } catch (e) {
      _fail(e);
      return null;
    }
  }

  Future<bool> confirmReset({
    required String resetToken,
    required String newPassword,
  }) async {
    _begin();
    try {
      await _repo.confirmReset(
        resetToken: resetToken,
        newPassword: newPassword,
      );
      _isLoading = false;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _fail(e);
      return false;
    }
  }

  Future<void> logout() async {
    await _logoutLocal();
  }

  Future<void> _logoutLocal() async {
    await _tokens.clear();
    _account = null;
    // The next student must never inherit this one's name or phone (the
    // video watermark reads them).
    _currentUser = _blankUser;
    _lastDevOtp = null;
    _pendingVerificationEmail = null;
    _status = AuthStatus.unauthenticated;
    _isLoading = false;
    notifyListeners();
  }

  void updateProfile(UserProfile updatedProfile) {
    _currentUser = updatedProfile;
    notifyListeners();
  }

  @override
  void dispose() {
    _api.dispose();
    _apiWithCallbacks.dispose();
    super.dispose();
  }
}
