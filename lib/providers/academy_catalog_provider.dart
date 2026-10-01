import 'package:flutter/foundation.dart';

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

/// Student-facing academy catalog: levels, the published subjects of every
/// level, and per-subject detail, all read through [AcademyRepository].
///
/// The catalog loads as one unit (levels, then every level's subjects) so the
/// home and courses screens share a single loading / error / ready state and
/// one retry. The server is the only source of what a student owns: nothing
/// here ever sets `owned` or a video id.
class AcademyCatalogProvider extends ChangeNotifier {
  AcademyCatalogProvider(this._repository);

  final AcademyRepository _repository;

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
  Future<void> reload() async {
    if (_status == LoadStatus.loading) return;
    final generation = _generation;
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
      _settleSelection();
    } catch (e) {
      if (generation != _generation) return;
      _error = e;
      _status = LoadStatus.error;
    }
    notifyListeners();
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

  /// Asks the server whether the student may play [videoId] now and returns
  /// the playback answer. Nothing is kept here: the answer goes straight to
  /// the caller (the player screen), which must hold it in memory only.
  Future<VideoPlayback> requestPlayback(String videoId) =>
      _repository.playVideo(videoId);

  /// True when nothing has been loaded since construction or [reset].
  bool get isPristine => _status == LoadStatus.idle && _details.isEmpty;

  /// Drops everything (logout): ownership and detail are per student.
  /// Pass `notify: false` when called while a build is in progress.
  void reset({bool notify = true}) {
    _generation++;
    _status = LoadStatus.idle;
    _error = null;
    _levels = null;
    _subjectsByLevel = const {};
    _studyTypeKey = null;
    _levelKey = null;
    _searchQuery = '';
    _details.clear();
    if (notify) notifyListeners();
  }
}
