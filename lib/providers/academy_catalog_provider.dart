import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../core/catalog_cache.dart';
import '../core/haptics.dart';
import '../models/academy_catalog.dart';
import '../repositories/academy_repository.dart';

enum LoadStatus { idle, loading, ready, error }

/// Load state of one subject's detail.
class SubjectDetailState {
  const SubjectDetailState({
    this.status = LoadStatus.idle,
    this.detail,
    this.error,
  });

  final LoadStatus status;
  final AcademySubjectDetail? detail;
  final Object? error;
}

enum AccessRequestStatus { idle, sending, sent, failed }

/// Progress of this session's access request for one subject. The server is
/// the source of truth for whether a request is pending (the subject detail's
/// `request`); this only tracks the call made from this device, and the
/// support link its response carried.
class AccessRequestState {
  const AccessRequestState({
    this.status = AccessRequestStatus.idle,
    this.supportUrl,
    this.error,
  });

  final AccessRequestStatus status;

  /// `whatsapp_url` of the last successful request. The subject detail does
  /// not carry it, so it is null when the pending state came from the detail
  /// alone (for example after a restart).
  final String? supportUrl;
  final Object? error;

  /// A 404 or 409 will not change by asking again (unknown subject, already
  /// owned, or the subject's access date has passed); anything else may.
  bool get canRetry {
    final e = error;
    if (e is ApiException) return e.statusCode != 404 && e.statusCode != 409;
    return true;
  }
}

/// Student-facing academy catalog: levels, the published subjects of every
/// level, and per-subject detail, all read through [AcademyRepository].
///
/// The catalog loads as one unit (levels, then every level's subjects) so the
/// home and courses screens share a single loading / error / ready state and
/// one retry. The server is the only source of what a student owns: nothing
/// here ever sets `owned` or a video id.
class AcademyCatalogProvider extends ChangeNotifier {
  AcademyCatalogProvider(this._repository, {CatalogCache? cache})
    // ignore: prefer_initializing_formals, public `cache:` maps to `_cache`
    : _cache = cache;

  final AcademyRepository _repository;
  final CatalogCache? _cache;

  /// True while the shown catalog comes from the on-device cache because the
  /// last reload could not reach the server. The UI shows the offline banner
  /// with a retry; the next successful reload clears it.
  bool _isStale = false;
  bool get isStale => _isStale;

  /// When the shown data was last fetched from the server (or cache write).
  DateTime? _lastUpdated;
  DateTime? get lastUpdated => _lastUpdated;

  /// Server cap per page (`limit` is clamped to 100).
  static const _pageSize = 100;

  /// Safety bound on pages fetched per level.
  static const _maxPages = 20;

  LoadStatus _status = LoadStatus.idle;
  Object? _error;
  AcademyLevels? _levels;
  Map<String, List<AcademySubject>> _subjectsByLevel = const {};
  String? _studyTypeKey;
  String? _levelKey;
  String _searchQuery = '';
  final Map<String, SubjectDetailState> _details = {};
  final Map<String, AccessRequestState> _access = {};

  /// Bumped on [reset] so a response that arrives after logout is dropped.
  int _generation = 0;

  LoadStatus get status => _status;
  bool get isLoading => _status == LoadStatus.loading;
  bool get hasError => _status == LoadStatus.error;
  bool get isReady => _status == LoadStatus.ready;

  /// The failure behind [hasError]; map it with `ErrorMessages.forCatalog`.
  Object? get error => _error;

  /// Study types in server order. Falls back to grouping [levels] by
  /// `study_type` when the server sent no `study_types` list.
  List<AcademyStudyType> get studyTypes {
    final levels = _levels;
    if (levels == null) return const [];
    if (levels.studyTypes.isNotEmpty) return levels.studyTypes;
    final order = <String>[];
    final grouped = <String, List<AcademyLevel>>{};
    for (final l in levels.levels) {
      grouped
          .putIfAbsent(l.studyType, () {
            order.add(l.studyType);
            return [];
          })
          .add(l);
    }
    return [
      for (final key in order)
        AcademyStudyType(
          key: key,
          title: LocalizedText(ar: key, en: key),
          levels: grouped[key]!,
        ),
    ];
  }

  String? get selectedStudyTypeKey => _studyTypeKey;
  String? get selectedLevelKey => _levelKey;

  AcademyStudyType? get selectedStudyType {
    for (final t in studyTypes) {
      if (t.key == _studyTypeKey) return t;
    }
    return null;
  }

  /// Levels of the selected study type, ordered by `position`.
  List<AcademyLevel> get levelsOfSelectedType {
    final type = selectedStudyType;
    if (type == null) return const [];
    final sorted = [...type.levels]
      ..sort((a, b) => a.position.compareTo(b.position));
    return sorted;
  }

  AcademyLevel? get selectedLevel {
    for (final l in levelsOfSelectedType) {
      if (l.key == _levelKey) return l;
    }
    return null;
  }

  /// Every published subject of [levelKey], unfiltered.
  List<AcademySubject> subjectsOf(String levelKey) =>
      _subjectsByLevel[levelKey] ?? const [];

  String get searchQuery => _searchQuery;

  /// Subjects of the selected level that match the search query (title or
  /// description, either language).
  List<AcademySubject> get visibleSubjects {
    final key = _levelKey;
    if (key == null) return const [];
    final all = subjectsOf(key);
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return all;
    bool hit(LocalizedText t) =>
        t.ar.toLowerCase().contains(q) || t.en.toLowerCase().contains(q);
    return all.where((s) => hit(s.title) || hit(s.description)).toList();
  }

  /// Subjects the server reports as owned, across all levels.
  List<AcademySubject> get ownedSubjects => [
    for (final list in _subjectsByLevel.values)
      for (final s in list)
        if (s.owned) s,
  ];

  /// A listed subject by id, or null.
  AcademySubject? findSubject(String id) {
    for (final list in _subjectsByLevel.values) {
      for (final s in list) {
        if (s.id == id) return s;
      }
    }
    return null;
  }

  /// Loads the catalog once. Does nothing while loading or after success.
  Future<void> ensureLoaded() async {
    if (_status == LoadStatus.idle) await reload();
  }

  /// (Re)loads levels and the subjects of every level.
  ///
  /// Success replaces the on-device cache. On a network error, timeout or
  /// transient server failure, the last cached catalog (levels, subjects and
  /// their `owned`/`access_expires_at` entitlements) is shown with the
  /// offline banner ([isStale]) instead of an error; anything else, or no
  /// cache, is an error with retry.
  Future<void> reload() async {
    if (_status == LoadStatus.loading) return;
    final generation = _generation;
    final hadData = _levels != null;
    _status = LoadStatus.loading;
    _error = null;
    notifyListeners();
    try {
      final levels = await _repository.levels();
      final lists = await Future.wait(
        levels.levels.map((l) => _allSubjects(l.key)),
      );
      if (generation != _generation) return;
      _levels = levels;
      _subjectsByLevel = {
        for (var i = 0; i < levels.levels.length; i++)
          levels.levels[i].key: lists[i],
      };
      _status = LoadStatus.ready;
      _isStale = false;
      _lastUpdated = DateTime.now().toUtc();
      _settleSelection();
      unawaited(_writeCache(levels, _subjectsByLevel));
    } catch (e) {
      if (generation != _generation) return;
      // Keep in-memory data when a refresh fails transiently.
      if (hadData && _isOfflineError(e)) {
        _status = LoadStatus.ready;
        _isStale = true;
        notifyListeners();
        return;
      }
      // Cold start offline: fall back to the on-device cache.
      if (!hadData && _isOfflineError(e)) {
        final cached = await _cache?.read();
        if (cached != null && generation == _generation) {
          final restored = _restoreSnapshot(cached);
          if (restored) {
            _status = LoadStatus.ready;
            _isStale = true;
            _error = null;
            _settleSelection();
            notifyListeners();
            return;
          }
        }
      }
      _error = e;
      _status = LoadStatus.error;
    }
    notifyListeners();
  }

  /// Network error, timeout or transient server failure: the cached data may
  /// be shown instead of an error. Auth failures (401/403/404) and other 4xx
  /// are answered errors, never a reason to serve stale data.
  static bool _isOfflineError(Object e) {
    if (e is ApiException) {
      if (e.code == 'timeout') return true;
      final s = e.statusCode;
      return s <= 0 || s >= 500 || s == 408 || s == 429;
    }
    // SocketException, TimeoutException, client errors: offline.
    return true;
  }

  Future<void> _writeCache(
    AcademyLevels levels,
    Map<String, List<AcademySubject>> subjects,
  ) async {
    final cache = _cache;
    if (cache == null) return;
    try {
      await cache.write(
        CatalogSnapshot(
          levelsJson: levels.toJson(),
          subjectsJson: {
            for (final e in subjects.entries)
              e.key: [for (final s in e.value) s.toJson()],
          },
          savedAt: DateTime.now().toUtc(),
        ),
      );
      _lastUpdated ??= DateTime.now().toUtc();
    } catch (_) {
      // A failed cache write must never fail the reload.
    }
  }

  /// Populates [_levels] and [_subjectsByLevel] from a cache snapshot.
  /// Returns false when the snapshot does not parse.
  bool _restoreSnapshot(CatalogSnapshot snapshot) {
    try {
      final levels = AcademyLevels.fromJson(snapshot.levelsJson);
      final subjects = <String, List<AcademySubject>>{};
      snapshot.subjectsJson.forEach((key, items) {
        subjects[key] = [
          for (final item in items) AcademySubject.fromJson(item),
        ];
      });
      _levels = levels;
      _subjectsByLevel = subjects;
      _lastUpdated = snapshot.savedAt;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<AcademySubject>> _allSubjects(String levelKey) async {
    final all = <AcademySubject>[];
    for (var page = 1; page <= _maxPages; page++) {
      final res = await _repository.subjects(
        levelKey: levelKey,
        page: page,
        limit: _pageSize,
      );
      all.addAll(res.items);
      if (!res.hasMore || res.items.isEmpty) break;
    }
    return all;
  }

  /// Keeps the current selection while it is still valid, otherwise picks
  /// the first study type and its first level.
  void _settleSelection() {
    final types = studyTypes;
    if (types.isEmpty) {
      _studyTypeKey = null;
      _levelKey = null;
      return;
    }
    if (!types.any((t) => t.key == _studyTypeKey)) {
      _studyTypeKey = types.first.key;
      _levelKey = null;
    }
    final levels = levelsOfSelectedType;
    if (!levels.any((l) => l.key == _levelKey)) {
      _levelKey = levels.isEmpty ? null : levels.first.key;
    }
  }

  void selectStudyType(String key) {
    if (key == _studyTypeKey) return;
    if (!studyTypes.any((t) => t.key == key)) return;
    _studyTypeKey = key;
    _levelKey = null;
    _settleSelection();
    notifyListeners();
  }

  void selectLevel(String key) {
    if (key == _levelKey) return;
    if (!levelsOfSelectedType.any((l) => l.key == key)) return;
    _levelKey = key;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    if (query == _searchQuery) return;
    _searchQuery = query;
    notifyListeners();
  }

  void clearSearch() => setSearchQuery('');

  SubjectDetailState detailOf(String id) =>
      _details[id] ?? const SubjectDetailState();

  /// Loads one subject's detail. Cached after success; [force] (retry or
  /// refresh) refetches. Concurrent calls for the same id share one request.
  Future<void> loadDetail(String id, {bool force = false}) async {
    final current = detailOf(id);
    if (current.status == LoadStatus.loading) return;
    if (current.status == LoadStatus.ready && !force) return;
    final generation = _generation;
    _details[id] = SubjectDetailState(
      status: LoadStatus.loading,
      detail: current.detail,
    );
    notifyListeners();
    try {
      final detail = await _repository.subject(id);
      if (generation != _generation) return;
      _details[id] = SubjectDetailState(
        status: LoadStatus.ready,
        detail: detail,
      );
    } catch (e) {
      if (generation != _generation) return;
      _details[id] = SubjectDetailState(status: LoadStatus.error, error: e);
    }
    notifyListeners();
  }

  AccessRequestState accessOf(String id) =>
      _access[id] ?? const AccessRequestState();

  /// Opens a subject: loads its detail and, when the student neither owns it
  /// nor has a pending request, creates the access request (SPEC decision 9).
  /// Meant to be called once per screen open (and on retry), never from a
  /// build. A cached subject the student does not own is refetched, so a
  /// request that was accepted or rejected meanwhile shows up.
  Future<void> openSubject(String id, {bool force = false}) async {
    // A failure from an earlier visit must not show while this one loads.
    if (accessOf(id).status == AccessRequestStatus.failed) _access.remove(id);
    final cached = detailOf(id).detail;
    await loadDetail(id, force: force || (cached != null && !cached.owned));
    final state = detailOf(id);
    final detail = state.detail;
    if (state.status != LoadStatus.ready || detail == null) return;
    if (detail.owned || detail.hasPendingRequest) return;
    await requestAccess(id);
  }

  /// `POST /academy/subjects/{id}/access-request`, then refreshes the detail
  /// so the server's `request` is what the screen shows. The server answers a
  /// repeat call with the existing pending request, so calling again is safe.
  /// A failure is kept in [accessOf] (map it with
  /// `ErrorMessages.forAccessRequest`); it is never retried automatically.
  Future<void> requestAccess(String id) async {
    if (accessOf(id).status == AccessRequestStatus.sending) return;
    final generation = _generation;
    _access[id] = const AccessRequestState(status: AccessRequestStatus.sending);
    notifyListeners();
    try {
      final res = await _repository.requestAccess(id);
      if (generation != _generation) return;
      _access[id] = AccessRequestState(
        status: AccessRequestStatus.sent,
        supportUrl: res.supportUrl,
      );
      AppHaptics.light();
      notifyListeners();
    } catch (e) {
      if (generation != _generation) return;
      _access[id] = AccessRequestState(
        status: AccessRequestStatus.failed,
        error: e,
      );
      notifyListeners();
      return;
    }
    await loadDetail(id, force: true);
  }

  /// Asks the server whether the student may play [videoId] now and returns
  /// the playback answer. Nothing is kept here: the answer goes straight to
  /// the caller (the player screen), which must hold it in memory only.
  Future<VideoPlayback> requestPlayback(String videoId) =>
      _repository.playVideo(videoId);

  /// True when nothing has been loaded since construction or [reset].
  bool get isPristine => _status == LoadStatus.idle && _details.isEmpty;

  /// Drops everything (logout): ownership and detail are per student.
  /// Pass `notify: false` when called while a build is in progress. The
  /// on-device cache is cleared too so the next student never sees this
  /// one's entitlements.
  void reset({bool notify = true}) {
    _generation++;
    _status = LoadStatus.idle;
    _error = null;
    _isStale = false;
    _lastUpdated = null;
    _levels = null;
    _subjectsByLevel = const {};
    _studyTypeKey = null;
    _levelKey = null;
    _searchQuery = '';
    _details.clear();
    _access.clear();
    final cache = _cache;
    if (cache != null) unawaited(cache.clear());
    if (notify) notifyListeners();
  }
}
