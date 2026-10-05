import 'dart:async';
import 'package:flutter/foundation.dart'
    show ChangeNotifier, kDebugMode, visibleForTesting;
import 'package:flutter/widgets.dart' show GlobalKey, NavigatorState;
import '../core/api_client.dart';
import '../core/app_config.dart';
import '../core/device_id.dart';
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
    String? Function()? localeReader,
  }) : _tokens = tokenStore ?? SecureTokenStore(),
       _localeReader = localeReader,
       _api =
           api ??
           ApiClient(
             baseUrl: AppConfig.baseUrl,
             allowSelfSigned: AppConfig.allowSelfSigned,
             localeReader: localeReader,
           ) {
    _repo = repository ?? HttpAuthRepository(_plainApi());
    _apiWithCallbacks = ApiClient(
      baseUrl: AppConfig.baseUrl,
      allowSelfSigned: AppConfig.allowSelfSigned,
      accessTokenReader: _tokens.readAccessToken,
      refreshTokens: _doRefresh,
      localeReader: _localeReader,
      onSessionReplaced: (msg) => handleSessionReplaced(msg),
    );
  }

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  final String? Function()? _localeReader;
  String? _forcedLocale;

  @visibleForTesting
  void setLocaleForTesting(String locale) {
    _forcedLocale = locale;
  }

  bool get _isArabic {
    final forced = _forcedLocale;
    if (forced != null) return forced.startsWith('ar');
    final reader = _localeReader;
    if (reader != null) {
      final lang = reader();
      if (lang != null) return lang.startsWith('ar');
    }
    return false;
  }

  ApiClient _plainApi() => ApiClient(
    baseUrl: AppConfig.baseUrl,
    allowSelfSigned: AppConfig.allowSelfSigned,
    localeReader: _localeReader,
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
  AuthAccount? _account;
  String? _pendingVerificationEmail;

  /// Pending signup session id issued at signup (rotated on replacement,
  /// kept on resend, cleared on verification). Sent with verify-otp.
  String? _pendingVerificationId;

  /// Last dev OTP returned by the backend in local mode. Set in debug
  /// builds only; always null in release builds.
  String? _lastDevOtp;

  static const _blankUser = UserProfile(
    id: 'pending',
    fullName: '',
    email: '',
    phone: '',
  );

  UserProfile _currentUser = _blankUser;

  AuthStatus get status => _status;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  UserProfile get currentUser => _currentUser;
  AuthAccount? get account => _account;
  String? get pendingVerificationEmail => _pendingVerificationEmail;
  String? get pendingVerificationId => _pendingVerificationId;
  String? get lastDevOtp => kDebugMode ? _lastDevOtp : null;

  void _begin() {
    _isLoading = true;
    _errorMessage = null;
    _logoutNotice = null;
    notifyListeners();
  }

  void _fail(Object e) {
    _isLoading = false;
    _errorMessage = _messageFor(e);
    notifyListeners();
  }

  String _messageFor(Object e) {
    return ErrorMessages.forException(e, isArabic: _isArabic);
  }

  String? _logoutNotice;
  String? get logoutNotice => _logoutNotice;

  void clearLogoutNotice() {
    _logoutNotice = null;
    notifyListeners();
  }

  Future<String> getDeviceId() => DeviceIdManager.getOrCreateDeviceId(_tokens);

  Future<void> handleSessionReplaced([String? backendMessage]) async {
    await _logoutLocal();
    _errorMessage = (backendMessage != null && backendMessage.isNotEmpty)
        ? backendMessage
        : ErrorMessages.sessionReplaced(_isArabic);
    notifyListeners();
    navigatorKey.currentState?.pushNamedAndRemoveUntil(
      '/login',
      (route) => false,
    );
  }

  Future<void> _storeSession(AuthAccount account, AuthTokens tokens) async {
    await _tokens.writeTokens(access: tokens.access, refresh: tokens.refresh);
    _account = account;
    _currentUser = _withAccount(_currentUser, account);
    _status = AuthStatus.authenticated;
    _pendingVerificationEmail = null;
    _pendingVerificationId = null;
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
      if (e.code == 'session_replaced') {
        await handleSessionReplaced(e.message);
        return false;
      }
      if (e.statusCode == 401 || e.statusCode == 403) {
        await _logoutLocal();
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Splash gate: restores the session when a stored token still validates.
  ///
  /// - No stored access token: unauthenticated.
  /// - `/me` 200: authenticated.
  /// - `/me` 401: runs the refresh once ([_doRefresh], the same callback
  ///   [ApiClient] uses). Success: `/me` again, stay logged in. Refresh
  ///   rejected (401/other 4xx): the tokens are already cleared, go to
  ///   login. Transient refresh failure: keep the tokens, enter offline.
  /// - `session_replaced`: message, then login (unchanged).
  /// - Network error, timeout or 5xx: keep the tokens and enter the app
  ///   offline (cached profile, banner, revalidate on resume/retry).
  Future<void> tryRestore() async {
    final access = await _tokens.readAccessToken();
    if (access == null || access.isEmpty) {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }
    try {
      await _restoreWith(access);
    } on ApiException catch (e) {
      if (e.code == 'session_replaced') {
        await handleSessionReplaced(e.message);
        return;
      }
      if (e.statusCode == 401) {
        await _restoreAfterRefresh();
        return;
      }
      if (_isTransientStatus(e.statusCode)) {
        _enterOffline();
        return;
      }
      await _logoutLocal();
    } catch (_) {
      _enterOffline();
    }
    notifyListeners();
  }

  /// Retry entry point for the offline banner and app-resume revalidation.
  Future<void> retryRestore() async {
    _offline = false;
    notifyListeners();
    await tryRestore();
  }

  /// True while the app runs on kept tokens because the last restore could
  /// not reach the server (network error, timeout or 5xx). The UI shows an
  /// offline banner with a retry action.
  bool _offline = false;
  bool get isOffline => _offline;

  /// HTTP statuses that mean "the server did not answer": no response at
  /// all (-1: network error, timeout) or a 5xx. Anything else 4xx answered
  /// and disagrees with the tokens, so they are dropped.
  static bool _isTransientStatus(int status) => status <= 0 || status >= 500;

  Future<void> _restoreWith(String access) async {
    final account = await _repo.me(accessToken: access);
    _account = account;
    _currentUser = _withAccount(_currentUser, account);
    _status = AuthStatus.authenticated;
    _offline = false;
    _isLoading = false;
  }

  Future<void> _restoreAfterRefresh() async {
    final ok = await _doRefresh();
    if (!ok) {
      // Rejected (401/4xx/missing token): _doRefresh already cleared the
      // tokens (or showed the replaced message). Anything else is a
      // transient refresh failure: the tokens are still stored, so the
      // student stays in the app offline instead of being logged out.
      final access = await _tokens.readAccessToken();
      if (access == null || access.isEmpty) return;
      _enterOffline();
      return;
    }
    final access = await _tokens.readAccessToken();
    if (access == null || access.isEmpty) {
      await _logoutLocal();
      return;
    }
    try {
      await _restoreWith(access);
    } on ApiException catch (e) {
      if (e.code == 'session_replaced') {
        await handleSessionReplaced(e.message);
        return;
      }
      if (_isTransientStatus(e.statusCode)) {
        _enterOffline();
        return;
      }
      await _logoutLocal();
    } catch (_) {
      _enterOffline();
    }
  }

  void _enterOffline() {
    _offline = true;
    _status = AuthStatus.authenticated;
    _isLoading = false;
  }

  Future<bool> login(
    String identifier,
    String password, {
    String? deviceId,
    String? deviceLabel,
  }) async {
    _begin();
    final email = identifier.trim();
    if (email.isEmpty || password.isEmpty) {
      _isLoading = false;
      _errorMessage = ErrorMessages.allFieldsRequired(_isArabic);
      notifyListeners();
      return false;
    }
    try {
      final devId =
          deviceId ?? await DeviceIdManager.getOrCreateDeviceId(_tokens);
      final tokens = await _repo.login(
        email: email,
        password: password,
        deviceId: devId,
        deviceLabel: deviceLabel,
      );
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
      // Initial copy from signup; /auth/me returns both fields on subsequent fetches.
      _currentUser = _currentUser.copyWith(
        fullName: fullName.trim(),
        phone: phone.trim(),
      );
      _isLoading = false;
      _status = AuthStatus.needsVerification;
      _pendingVerificationEmail = email.trim();
      _pendingVerificationId = result.pendingId;
      notifyListeners();
      return true;
    } catch (e) {
      _fail(e);
      return false;
    }
  }

  Future<bool> verifyOtp({
    required String email,
    required String code,
    String? deviceId,
    String? deviceLabel,
  }) async {
    _begin();
    try {
      final devId =
          deviceId ?? await DeviceIdManager.getOrCreateDeviceId(_tokens);
      final tokens = await _repo.verifyOtp(
        email: email.trim(),
        code: code.trim(),
        deviceId: devId,
        deviceLabel: deviceLabel,
        pendingId: _pendingVerificationId,
      );
      final account = await _repo.me(accessToken: tokens.access);
      await _storeSession(account, tokens);
      return true;
    } catch (e) {
      _fail(e);
      return false;
    }
  }

  /// Resends the signup OTP for an unverified pending email.
  /// The backend answer is always generic; true means the call succeeded
  /// (a new code was sent unless throttled). Updates the debug OTP when present.
  Future<bool> resendSignupOtp({required String email}) async {
    _begin();
    try {
      final devOtp = await _repo.resendSignup(email: email.trim());
      _lastDevOtp = kDebugMode ? devOtp ?? _lastDevOtp : null;
      _isLoading = false;
      // Keep the pending email so the OTP screen stays in context.
      _pendingVerificationEmail = email.trim();
      notifyListeners();
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

  Future<bool> logout() async {
    final access = await _tokens.readAccessToken();
    bool confirmed = true;
    if (access != null && access.isNotEmpty) {
      try {
        await _repo.logout(accessToken: access);
        confirmed = true;
      } on ApiException catch (e) {
        if (e.statusCode == 204 || e.statusCode == 401) {
          confirmed = true;
        } else {
          confirmed = false;
        }
      } catch (_) {
        confirmed = false;
      }
    }
    await _logoutLocal();
    _errorMessage = null;
    if (!confirmed) {
      _logoutNotice = ErrorMessages.signOutUnconfirmed(_isArabic);
    }
    notifyListeners();
    return confirmed;
  }

  Future<void> _logoutLocal() async {
    await _tokens.clear();
    _account = null;
    // The next student must never inherit this one's name or phone (the
    // video watermark reads them).
    _currentUser = _blankUser;
    _lastDevOtp = null;
    _pendingVerificationEmail = null;
    _pendingVerificationId = null;
    _status = AuthStatus.unauthenticated;
    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _api.dispose();
    _apiWithCallbacks.dispose();
    super.dispose();
  }
}
