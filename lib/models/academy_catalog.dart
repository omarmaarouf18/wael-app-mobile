/// Dart models for the academy-service student API
/// (`GET /api/v1/academy/levels`, `/subjects`, `/subjects/{id}`).
///
/// Field names and shapes mirror the Go DTOs in
/// `services/academy-service/internal/models` exactly (snake_case in JSON).
/// Parsing is strict about required fields: a response that does not match
/// the contract raises [AcademyParseException] instead of producing a
/// half-filled object.
library;

/// Thrown when a response body does not match the academy DTO contract.
class AcademyParseException implements Exception {
  AcademyParseException(this.message);

  final String message;

  @override
  String toString() => 'AcademyParseException: $message';
}

Map<String, dynamic> _map(Object? json, String what) {
  if (json is Map<String, dynamic>) return json;
  throw AcademyParseException('$what: expected an object');
}

String _requiredString(Map<String, dynamic> json, String key) {
  final v = json[key];
  if (v is String && v.isNotEmpty) return v;
  throw AcademyParseException('missing or empty "$key"');
}

String _string(Map<String, dynamic> json, String key) {
  final v = json[key];
  return v is String ? v : '';
}

int _int(Map<String, dynamic> json, String key) {
  final v = json[key];
  if (v is int) return v;
  if (v is num) return v.toInt();
  throw AcademyParseException('missing or non-numeric "$key"');
}

List<Object?> _list(Map<String, dynamic> json, String key) {
  final v = json[key];
  if (v is List) return v;
  throw AcademyParseException('missing list "$key"');
}

/// Go serialises an unset `time.Time` as `0001-01-01T00:00:00Z`; that and
/// anything unparsable mean "no expiry set" (null).
DateTime? _parseExpiry(Object? v) {
  if (v is! String || v.isEmpty) return null;
  final parsed = DateTime.tryParse(v);
  if (parsed == null || parsed.year <= 1) return null;
  return parsed.toUtc();
}

/// Bilingual text (`{"ar": "...", "en": "..."}`). Arabic is required by the
/// backend, English optional; the UI prefers the active language and falls
/// back to the other.
class LocalizedText {
  const LocalizedText({this.ar = '', this.en = ''});

  final String ar;
  final String en;

  factory LocalizedText.fromJson(Object? json) {
    final m = _map(json, 'localized text');
    return LocalizedText(ar: _string(m, 'ar'), en: _string(m, 'en'));
  }

  String resolve(bool isArabic) {
    if (isArabic) return ar.isNotEmpty ? ar : en;
    return en.isNotEmpty ? en : ar;
  }
}

/// A level (academic year or programme tier): `LevelDTO`.
class AcademyLevel {
  const AcademyLevel({
    required this.key,
    required this.studyType,
    required this.title,
    required this.position,
  });

  final String key;
  final String studyType;
  final LocalizedText title;
  final int position;

  factory AcademyLevel.fromJson(Object? json) {
    final m = _map(json, 'level');
    return AcademyLevel(
      key: _requiredString(m, 'key'),
      studyType: _requiredString(m, 'study_type'),
      title: LocalizedText.fromJson(m['title']),
      position: _int(m, 'position'),
    );
  }
}

/// A study type with its levels: `StudyTypeDTO`.
class AcademyStudyType {
  const AcademyStudyType({
    required this.key,
    required this.title,
    required this.levels,
  });

  final String key;
  final LocalizedText title;
  final List<AcademyLevel> levels;

  factory AcademyStudyType.fromJson(Object? json) {
    final m = _map(json, 'study type');
    return AcademyStudyType(
      key: _requiredString(m, 'key'),
      title: LocalizedText.fromJson(m['title']),
      levels: _list(m, 'levels').map(AcademyLevel.fromJson).toList(),
    );
  }
}

/// `GET /academy/levels`: `LevelsResponseDTO`. `study_types` is omitted by the
/// server when empty, so it defaults to an empty list.
class AcademyLevels {
  const AcademyLevels({required this.levels, required this.studyTypes});

  final List<AcademyLevel> levels;
  final List<AcademyStudyType> studyTypes;

  factory AcademyLevels.fromJson(Map<String, dynamic> json) {
    final raw = json['study_types'];
    return AcademyLevels(
      levels: _list(json, 'levels').map(AcademyLevel.fromJson).toList(),
      studyTypes: raw is List
          ? raw.map(AcademyStudyType.fromJson).toList()
          : const [],
    );
  }
}

/// `SubjectCountsDTO`.
class SubjectCounts {
  const SubjectCounts({this.videos = 0, this.books = 0, this.notes = 0});

  final int videos;
  final int books;
  final int notes;

  int get total => videos + books + notes;

  factory SubjectCounts.fromJson(Object? json) {
    final m = _map(json, 'counts');
    return SubjectCounts(
      videos: _int(m, 'videos'),
      books: _int(m, 'books'),
      notes: _int(m, 'notes'),
    );
  }
}

/// A subject as listed by `GET /academy/subjects`: `SubjectListItemDTO`.
///
/// [price] and [currency] are null unless the server exposes prices
/// (`EXPOSE_PRICE_TO_STUDENTS`, SPEC decision D3). [owned] is false until the
/// student holds an unexpired entitlement. [accessExpiresAt] is null when the
/// server sent no real date.
class AcademySubject {
  const AcademySubject({
    required this.id,
    required this.levelKey,
    required this.term,
    required this.title,
    required this.description,
    required this.owned,
    required this.counts,
    this.price,
    this.currency,
    this.accessExpiresAt,
  });

  final String id;
  final String levelKey;

  /// `first`, `second`, or empty (vocational and other term-less subjects).
  final String term;
  final LocalizedText title;
  final LocalizedText description;
  final bool owned;
  final SubjectCounts counts;
  final int? price;
  final String? currency;
  final DateTime? accessExpiresAt;

  bool get hasTerm => term.isNotEmpty;

  factory AcademySubject.fromJson(Object? json) =>
      AcademySubject._parse(_map(json, 'subject'));

  AcademySubject._parse(Map<String, dynamic> m)
    : id = _requiredString(m, 'id'),
      levelKey = _requiredString(m, 'level_key'),
      term = _string(m, 'term'),
      title = LocalizedText.fromJson(m['title']),
      description = m['description'] == null
          ? const LocalizedText()
          : LocalizedText.fromJson(m['description']),
      // A missing flag must never unlock anything.
      owned = m['owned'] == true,
      counts = SubjectCounts.fromJson(m['counts']),
      price = m['price'] is num ? (m['price'] as num).toInt() : null,
      currency = m['currency'] is String && (m['currency'] as String).isNotEmpty
          ? m['currency'] as String
          : null,
      accessExpiresAt = _parseExpiry(m['access_expires_at']);
}

/// `SubjectListResponseDTO`.
class SubjectPage {
  const SubjectPage({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
  });

  final List<AcademySubject> items;
  final int total;
  final int page;
  final int limit;

  bool get hasMore => page * limit < total;

  factory SubjectPage.fromJson(Map<String, dynamic> json) => SubjectPage(
    items: _list(json, 'items').map(AcademySubject.fromJson).toList(),
    total: _int(json, 'total'),
    page: _int(json, 'page'),
    limit: _int(json, 'limit'),
  );
}

/// `VideoMetadataDTO`. The server does not send `youtube_video_id` until the
/// student owns the subject (SPEC R2, Phase 3.2). When a value arrives it is
/// kept only if it has the shape of a YouTube id, and nothing in the app builds
/// a YouTube URL from anything else.
class AcademyVideo {
  const AcademyVideo({
    required this.id,
    required this.position,
    required this.title,
    required this.description,
    this.youtubeVideoId,
  });

  final String id;
  final int position;
  final LocalizedText title;
  final LocalizedText description;
  final String? youtubeVideoId;

  bool get hasVideoId => youtubeVideoId != null;

  static final _youtubeId = RegExp(r'^[A-Za-z0-9_-]{11}$');

  factory AcademyVideo.fromJson(Object? json) {
    final m = _map(json, 'video');
    final rawId = m['youtube_video_id'];
    return AcademyVideo(
      id: _requiredString(m, 'id'),
      position: _int(m, 'position'),
      title: LocalizedText.fromJson(m['title']),
      description: m['description'] == null
          ? const LocalizedText()
          : LocalizedText.fromJson(m['description']),
      youtubeVideoId: rawId is String && _youtubeId.hasMatch(rawId)
          ? rawId
          : null,
    );
  }
}

/// `FileMetadataDTO`: a PDF attached to a subject. [kind] is `book` or `note`.
/// The server sends no storage key and no download capability here.
class AcademyFile {
  const AcademyFile({
    required this.id,
    required this.kind,
    required this.title,
    required this.sizeBytes,
  });

  final String id;
  final String kind;
  final LocalizedText title;
  final int sizeBytes;

  bool get isBook => kind == 'book';
  bool get isNote => kind == 'note';

  factory AcademyFile.fromJson(Object? json) {
    final m = _map(json, 'file');
    return AcademyFile(
      id: _requiredString(m, 'id'),
      kind: _requiredString(m, 'kind'),
      title: LocalizedText.fromJson(m['title']),
      sizeBytes: _int(m, 'size_bytes'),
    );
  }
}

/// `GET /academy/subjects/{id}`: `SubjectDetailDTO`.
class AcademySubjectDetail extends AcademySubject {
  // `m` is also read by the initialisers, so it cannot be a super parameter.
  // ignore: use_super_parameters
  AcademySubjectDetail.fromJson(Map<String, dynamic> m)
    : videos = _list(m, 'videos').map(AcademyVideo.fromJson).toList(),
      files = _list(m, 'files').map(AcademyFile.fromJson).toList(),
      super._parse(m);

  final List<AcademyVideo> videos;
  final List<AcademyFile> files;

  List<AcademyFile> get books => files.where((f) => f.isBook).toList();
  List<AcademyFile> get notes => files.where((f) => f.isNote).toList();
}
