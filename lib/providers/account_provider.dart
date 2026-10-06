import 'package:flutter/foundation.dart' show ChangeNotifier;

import '../core/error_messages.dart';
import '../repositories/account_repository.dart';
import 'auth_provider.dart';

/// Self-service account actions (F-UX2 Part B): profile, password, email,
/// devices and deletion. Each call reports busy state and the last failure
/// as a clear localized message; success results are returned directly.
/// Holds no user data, so nothing resets on logout.
class AccountProvider extends ChangeNotifier {
  // Public parameter names stay stable for call sites; fields stay private.
  AccountProvider({
    required AuthProvider auth,
    AccountRepository? repository,
    String? Function()? localeReader,
  })
    // ignore: prefer_initializing_formals
    : _auth = auth,
       _repo = repository,
       // ignore: prefer_initializing_formals
       _localeReader = localeReader;

  final AuthProvider _auth;
  final AccountRepository? _repo;

  bool _busy = false;
  bool get isBusy => _busy;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  final String? Function()? _localeReader;

  bool get _isArabic {
    final lang = _localeReader?.call();
    if (lang != null) return lang.startsWith('ar');
    return _auth.isArabic;
  }

  Future<T?> _run<T>(Future<T> Function(AccountRepository repo) call) async {
    final repo = _repo;
    if (repo == null) {
      _errorMessage = ErrorMessages.requestFailed(_isArabic);
      notifyListeners();
      return null;
    }
    _busy = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final result = await call(repo);
      _busy = false;
      notifyListeners();
      return result;
    } catch (e) {
      _busy = false;
      _errorMessage = ErrorMessages.forAccountError(e, isArabic: _isArabic);
      notifyListeners();
      return null;
    }
  }

  /// Changes the name and/or phone with the current password. Refreshes the
  /// profile (and so the watermark source) on success.
  Future<ProfileUpdate?> updateProfile({
    String? fullName,
    String? phone,
    required String currentPassword,
  }) async {
    final updated = await _run(
      (repo) => repo.updateProfile(
        fullName: fullName,
        phone: phone,
        currentPassword: currentPassword,
      ),
    );
    if (updated != null) await _auth.refreshProfile();
    return updated;
  }

  /// Changes the password. Every other session ends server-side.
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    return await _run((repo) async {
          await repo.changePassword(
            currentPassword: currentPassword,
            newPassword: newPassword,
          );
          return true;
        }) ??
        false;
  }

  /// Starts the email change: the code goes to the new address. Always
  /// succeeds from the student's view (the server answers generic 200).
  Future<bool> requestEmailChange({
    required String newEmail,
    required String currentPassword,
  }) async {
    return await _run((repo) async {
          await repo.requestEmailChange(
            newEmail: newEmail,
            currentPassword: currentPassword,
          );
          return true;
        }) ??
        false;
  }

  /// Confirms the email change. All sessions (including this one) end
  /// server-side; the caller signs out locally.
  Future<bool> confirmEmailChange({required String code}) async {
    return await _run((repo) async {
          await repo.confirmEmailChange(code: code);
          return true;
        }) ??
        false;
  }

  /// The caller's signed-in devices, or null on failure.
  Future<List<DeviceSession>?> loadSessions() =>
      _run((repo) => repo.sessions());

  /// Ends one own session. Ending the current one is logout: the caller
  /// signs out locally afterwards.
  Future<bool> endSession(String sid) async {
    return await _run((repo) async {
          await repo.deleteSession(sid);
          return true;
        }) ??
        false;
  }

  /// Requests account deletion. Returns the purge date (`yyyy-MM-dd`) the
  /// server states, or null on failure.
  Future<String?> requestDeletion({required String currentPassword}) async {
    final date = await _run(
      (repo) => repo.requestDeletion(currentPassword: currentPassword),
    );
    return (date != null && date.isNotEmpty) ? date : null;
  }
}
