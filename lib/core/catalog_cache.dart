import 'dart:convert';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/services.dart'
    show MissingPluginException, PlatformException;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Cached catalog snapshot: the last levels + subjects lists the server
/// returned, with the ownership flags (`owned`, `access_expires_at`) they
/// carried. No PII beyond what `/auth/me` already caches (ids, titles,
/// owned flags); no tokens, no video ids, no names or phones.
///
/// Refresh replaces the cache. The provider shows it with an offline banner
/// when a reload fails with a network error or timeout.
class CatalogSnapshot {
  const CatalogSnapshot({
    required this.levelsJson,
    required this.subjectsJson,
    required this.savedAt,
  });

  /// Raw `AcademyLevels` JSON (`levels`, `study_types`).
  final Map<String, dynamic> levelsJson;

  /// Raw subjects by level key (`SubjectPage`-like `items` lists).
  final Map<String, List<Map<String, dynamic>>> subjectsJson;

  final DateTime savedAt;

  Map<String, dynamic> toJson() => {
    'levels': levelsJson,
    'subjects': subjectsJson,
    'savedAt': savedAt.toUtc().toIso8601String(),
  };

  factory CatalogSnapshot.fromJson(Map<String, dynamic> json) {
    final levels = (json['levels'] as Map?)?.cast<String, dynamic>() ?? {};
    final subjects = <String, List<Map<String, dynamic>>>{};
    final rawSubjects = json['subjects'];
    if (rawSubjects is Map) {
      rawSubjects.forEach((key, value) {
        if (value is List) {
          subjects[key.toString()] = [
            for (final item in value)
              if (item is Map) item.cast<String, dynamic>(),
          ];
        }
      });
    }
    final savedAt =
        DateTime.tryParse(json['savedAt']?.toString() ?? '')?.toUtc() ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    return CatalogSnapshot(
      levelsJson: levels,
      subjectsJson: subjects,
      savedAt: savedAt,
    );
  }

  String encode() => jsonEncode(toJson());

  static CatalogSnapshot? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return CatalogSnapshot.fromJson(decoded);
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}

/// Catalog snapshot persistence. Production binding is [SecureCatalogCache]
/// (platform keychain/keystore, same plugin as tokens). Tests inject
/// [MemoryCatalogCache].
abstract class CatalogCache {
  Future<CatalogSnapshot?> read();
  Future<void> write(CatalogSnapshot snapshot);
  Future<void> clear();
}

/// Secure-storage binding. Degrades to process memory when the platform
/// plugin is unavailable (widget tests, unsupported targets).
class SecureCatalogCache implements CatalogCache {
  SecureCatalogCache({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'wael_catalog_cache';

  final FlutterSecureStorage _storage;
  CatalogSnapshot? _fallback;

  @override
  Future<CatalogSnapshot?> read() async {
    try {
      final raw = await _storage.read(key: _key);
      return CatalogSnapshot.decode(raw) ?? _fallback;
    } on MissingPluginException catch (_) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('[SecureCatalogCache] plugin missing, using memory fallback');
      }
      return _fallback;
    } on PlatformException {
      return _fallback;
    }
  }

  @override
  Future<void> write(CatalogSnapshot snapshot) async {
    _fallback = snapshot;
    try {
      await _storage.write(key: _key, value: snapshot.encode());
    } on MissingPluginException catch (_) {
      // Memory fallback already updated.
    } on PlatformException {
      // Keep the memory fallback; a failed write must not crash reload.
    }
  }

  @override
  Future<void> clear() async {
    _fallback = null;
    try {
      await _storage.delete(key: _key);
    } on MissingPluginException catch (_) {
      // Memory fallback already cleared.
    } on PlatformException {
      // Memory fallback already cleared; a failed delete must not throw.
    }
  }
}

/// In-memory binding for unit/widget tests.
class MemoryCatalogCache implements CatalogCache {
  CatalogSnapshot? _snapshot;

  @override
  Future<CatalogSnapshot?> read() async => _snapshot;

  @override
  Future<void> write(CatalogSnapshot snapshot) async {
    _snapshot = snapshot;
  }

  @override
  Future<void> clear() async {
    _snapshot = null;
  }
}
