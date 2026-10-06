import 'dart:convert';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/services.dart'
    show MissingPluginException, PlatformException;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/app_config.dart';

/// Cached public app configuration with its fetch time. Small JSON in
/// secure storage (same plugin as tokens); refresh replaces it.
class AppConfigSnapshot {
  const AppConfigSnapshot({required this.config, required this.savedAt});

  final AppConfigData config;
  final DateTime savedAt;

  Map<String, dynamic> toJson() => {
    'config': config.toJson(),
    'savedAt': savedAt.toUtc().toIso8601String(),
  };

  factory AppConfigSnapshot.fromJson(Map<String, dynamic> json) {
    final raw = json['config'];
    final config = raw is Map<String, dynamic>
        ? AppConfigData.fromJson(raw)
        : const AppConfigData();
    final savedAt =
        DateTime.tryParse(json['savedAt']?.toString() ?? '')?.toUtc() ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    return AppConfigSnapshot(config: config, savedAt: savedAt);
  }

  String encode() => jsonEncode(toJson());

  static AppConfigSnapshot? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return AppConfigSnapshot.fromJson(decoded);
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}

/// App-config snapshot persistence. Production binding is
/// [SecureAppConfigCache] (platform keychain/keystore). Tests inject
/// [MemoryAppConfigCache].
abstract class AppConfigCache {
  Future<AppConfigSnapshot?> read();
  Future<void> write(AppConfigSnapshot snapshot);
}

/// Secure-storage binding. Degrades to process memory when the platform
/// plugin is unavailable (widget tests, unsupported targets).
class SecureAppConfigCache implements AppConfigCache {
  SecureAppConfigCache({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'wael_app_config';

  final FlutterSecureStorage _storage;
  AppConfigSnapshot? _fallback;

  @override
  Future<AppConfigSnapshot?> read() async {
    try {
      final raw = await _storage.read(key: _key);
      return AppConfigSnapshot.decode(raw) ?? _fallback;
    } on MissingPluginException catch (_) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('[SecureAppConfigCache] plugin missing, using memory fallback');
      }
      return _fallback;
    } on PlatformException {
      return _fallback;
    }
  }

  @override
  Future<void> write(AppConfigSnapshot snapshot) async {
    _fallback = snapshot;
    try {
      await _storage.write(key: _key, value: snapshot.encode());
    } on MissingPluginException catch (_) {
      // Memory fallback already updated.
    } on PlatformException {
      // Keep the memory fallback; a failed write must not crash refresh.
    }
  }
}

/// In-memory binding for tests.
class MemoryAppConfigCache implements AppConfigCache {
  AppConfigSnapshot? _snapshot;

  @override
  Future<AppConfigSnapshot?> read() async => _snapshot;

  @override
  Future<void> write(AppConfigSnapshot snapshot) async {
    _snapshot = snapshot;
  }
}
