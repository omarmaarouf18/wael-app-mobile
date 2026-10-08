import 'package:flutter/foundation.dart' show ChangeNotifier, visibleForTesting;
import 'package:package_info_plus/package_info_plus.dart';

import '../core/app_config_cache.dart';
import '../models/app_config.dart';
import '../repositories/academy_repository.dart';

/// Public app configuration (SPEC F-UX2 A7): the support WhatsApp link, the
/// terms/privacy page URLs and the optional update metadata.
///
/// The route is public and the fetch fails soft: offline, error or malformed
/// answers keep the last cached values, hide the update prompt and never
/// block the app. A cached copy younger than [cacheTtl] is reused.
class AppConfigProvider extends ChangeNotifier {
  AppConfigProvider({
    AcademyRepository? repository,
    AppConfigCache? cache,
    Future<String> Function()? versionReader,
    DateTime Function()? clock,
  }) : _repo = repository,
       _cache = cache ?? MemoryAppConfigCache(),
       _versionReader =
           versionReader ??
           (() async => (await PackageInfo.fromPlatform()).version),
       _clock = clock ?? DateTime.now;

  final AcademyRepository? _repo;
  final AppConfigCache _cache;
  final Future<String> Function() _versionReader;
  final DateTime Function() _clock;

  /// Freshness window for the cached copy (the server allows 5 min).
  static const cacheTtl = Duration(minutes: 5);

  AppConfigData _config = const AppConfigData();
  DateTime? _loadedAt;
  Future<void>? _pendingLoad;

  bool get isLoading => _pendingLoad != null;

  AppConfigData get config => _config;
  String get termsUrl => _config.termsUrl;
  String get privacyUrl => _config.privacyUrl;
  String get supportWhatsappUrl => _config.supportWhatsappUrl;

  /// Owner amendment 2026-10-08 (F-UX6): subject prices render only when
  /// this is true AND the subject carries a non-null price. False until
  /// the server sends a real boolean `true` (fail closed).
  bool get showPrices => _config.showPrices;

  /// Optional tutoring-center info for Settings > Help, null when the
  /// server omits it.
  CenterInfo? get center => _config.center;

  /// Notes and books downloads (`features.files`, client contract
  /// 2026-10-08, server pending). The last value the server sent is
  /// persisted on disk with the rest of the config ([SecureAppConfigCache],
  /// never cleared, kept past the 5-minute freshness window), so:
  ///
  /// - cold start with app-config unreachable: the persisted value, so
  ///   downloaded files still open and share offline;
  /// - a server answer replaces it: an explicit `false` (or a reachable
  ///   server that omits the field, fail closed) turns it off;
  /// - never fetched and nothing persisted: off.
  bool get filesEnabled => _config.filesEnabled;

  /// Loads the config unless a fresh copy is already in hand. Concurrent
  /// callers share one fetch.
  Future<void> load({bool force = false}) async {
    final pending = _pendingLoad;
    if (pending != null) return pending;
    if (!force && _loadedAt != null) {
      if (_clock().difference(_loadedAt!) < cacheTtl) return;
    }
    final future = _loadInternal(force: force);
    _pendingLoad = future;
    try {
      await future;
    } finally {
      _pendingLoad = null;
    }
  }

  Future<void> _loadInternal({bool force = false}) async {
    try {
      final cached = await _cache.read();
      if (cached != null && !force) {
        _config = cached.config;
        _loadedAt = cached.savedAt;
        if (_clock().difference(cached.savedAt) < cacheTtl) {
          notifyListeners();
          return;
        }
        // Stale copy: show its values (the persisted features.files among
        // them) right away, so a cold start on a hanging network does not
        // wait for the fetch to time out before downloaded files appear.
        notifyListeners();
      }
      final repo = _repo;
      if (repo == null) {
        if (cached == null) notifyListeners();
        return;
      }
      final fresh = await repo.appConfig();
      _config = fresh;
      _loadedAt = _clock();
      await _cache.write(AppConfigSnapshot(config: fresh, savedAt: _loadedAt!));
    } catch (_) {
      // Fail soft: keep the last values (possibly empty), no prompt.
    }
    notifyListeners();
  }

  /// The installed version, '' when the platform lookup fails. Read once.
  Future<String> currentVersion() async {
    final cached = _version;
    if (cached != null) return cached;
    try {
      _version = await _versionReader();
    } catch (_) {
      _version = '';
    }
    return _version!;
  }

  String? _version;

  /// Update state for [currentVersion]: required when below min_version,
  /// available when below latest_version, none otherwise (or when the
  /// versions are unknown).
  UpdateState updateState(String currentVersion) {
    if (currentVersion.isEmpty) return UpdateState.none;
    final cur = parseAppVersion(currentVersion);
    if (cur == null) return UpdateState.none;

    if (_config.minVersion.isNotEmpty) {
      final min = parseAppVersion(_config.minVersion);
      if (min != null && cur.compareTo(min) < 0) {
        return UpdateState.required;
      }
    }
    if (_config.latestVersion.isNotEmpty) {
      final latest = parseAppVersion(_config.latestVersion);
      if (latest != null && cur.compareTo(latest) < 0) {
        return UpdateState.available;
      }
    }
    return UpdateState.none;
  }

  @visibleForTesting
  void setForTesting(AppConfigData config) {
    _config = config;
    _loadedAt = _clock();
    notifyListeners();
  }
}

/// Whether the installed build should prompt for an update.
enum UpdateState {
  /// Current or newer than everything the server names: no prompt.
  none,

  /// Below latest_version: an "update available" tile.
  available,

  /// Below min_version: a blocking update screen at launch.
  required,
}
