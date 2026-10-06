import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/services.dart'
    show MissingPluginException, PlatformException;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Token persistence contract. Production binding is [SecureTokenStore]
/// (platform keychain/keystore). Tests inject [MemoryTokenStore].
///
/// The saved app language also lives here (`readLocale`/`writeLocale`):
/// no new dependency, and sign-out ([clear]) never resets the language.
/// The same holds for the single playback-speed preference
/// (`readPlaybackSpeed`/`writePlaybackSpeed`): one rate for every video.
abstract class TokenStore {
  Future<String?> readAccessToken();
  Future<String?> readRefreshToken();
  Future<void> writeTokens({required String access, required String refresh});
  Future<String?> readDeviceId();
  Future<void> writeDeviceId(String deviceId);
  Future<String?> readLocale();
  Future<void> writeLocale(String languageCode);
  Future<String?> readPlaybackSpeed();
  Future<void> writePlaybackSpeed(String rate);
  Future<void> clear();
}

/// Secure-storage binding. If the platform plugin is unavailable (widget
/// tests, unsupported targets) it degrades to process memory rather than
/// crashing; tokens then last only for the process lifetime.
class SecureTokenStore implements TokenStore {
  SecureTokenStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _accessKey = 'wael_access_token';
  static const _refreshKey = 'wael_refresh_token';
  static const _deviceIdKey = 'wael_device_id';
  static const _localeKey = 'wael_locale';
  static const _speedKey = 'wael_playback_speed';

  final FlutterSecureStorage _storage;
  final Map<String, String> _fallback = {};

  Future<T> _guard<T>(Future<T> Function() run, T fallback) async {
    try {
      return await run();
    } on MissingPluginException catch (_) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('[SecureTokenStore] plugin missing, using memory fallback');
      }
      return fallback;
    } on PlatformException {
      return fallback;
    }
  }

  @override
  Future<String?> readAccessToken() =>
      _guard(() => _storage.read(key: _accessKey), _fallback[_accessKey]);

  @override
  Future<String?> readRefreshToken() =>
      _guard(() => _storage.read(key: _refreshKey), _fallback[_refreshKey]);

  @override
  Future<String?> readDeviceId() =>
      _guard(() => _storage.read(key: _deviceIdKey), _fallback[_deviceIdKey]);

  @override
  Future<void> writeTokens({required String access, required String refresh}) {
    _fallback[_accessKey] = access;
    _fallback[_refreshKey] = refresh;
    return _guard(() async {
      await _storage.write(key: _accessKey, value: access);
      await _storage.write(key: _refreshKey, value: refresh);
    }, null);
  }

  @override
  Future<void> writeDeviceId(String deviceId) {
    _fallback[_deviceIdKey] = deviceId;
    return _guard(() async {
      await _storage.write(key: _deviceIdKey, value: deviceId);
    }, null);
  }

  @override
  Future<String?> readLocale() =>
      _guard(() => _storage.read(key: _localeKey), _fallback[_localeKey]);

  @override
  Future<void> writeLocale(String languageCode) {
    _fallback[_localeKey] = languageCode;
    return _guard(() async {
      await _storage.write(key: _localeKey, value: languageCode);
    }, null);
  }

  @override
  Future<String?> readPlaybackSpeed() =>
      _guard(() => _storage.read(key: _speedKey), _fallback[_speedKey]);

  @override
  Future<void> writePlaybackSpeed(String rate) {
    _fallback[_speedKey] = rate;
    return _guard(() async {
      await _storage.write(key: _speedKey, value: rate);
    }, null);
  }

  @override
  Future<void> clear() {
    _fallback.remove(_accessKey);
    _fallback.remove(_refreshKey);
    return _guard(() async {
      await _storage.delete(key: _accessKey);
      await _storage.delete(key: _refreshKey);
    }, null);
  }
}

/// In-memory binding for unit/widget tests.
class MemoryTokenStore implements TokenStore {
  String? _access;
  String? _refresh;
  String? _deviceId;
  String? _locale;
  String? _speed;

  @override
  Future<String?> readAccessToken() async => _access;

  @override
  Future<String?> readRefreshToken() async => _refresh;

  @override
  Future<String?> readDeviceId() async => _deviceId;

  @override
  Future<void> writeTokens({
    required String access,
    required String refresh,
  }) async {
    _access = access;
    _refresh = refresh;
  }

  @override
  Future<void> writeDeviceId(String deviceId) async {
    _deviceId = deviceId;
  }

  @override
  Future<String?> readLocale() async => _locale;

  @override
  Future<void> writeLocale(String languageCode) async {
    _locale = languageCode;
  }

  @override
  Future<String?> readPlaybackSpeed() async => _speed;

  @override
  Future<void> writePlaybackSpeed(String rate) async {
    _speed = rate;
  }

  @override
  Future<void> clear() async {
    _access = null;
    _refresh = null;
  }
}
