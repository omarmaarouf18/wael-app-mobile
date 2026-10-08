/// Dart models for the academy-service student API
/// (`GET /api/v1/academy/levels`, `/subjects`, `/subjects/{id}`, and
/// `POST /subjects/{id}/access-request`).
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

/// A list the server may omit or send as `null` (Go serialises a nil slice
/// as `null`; an older or newer server may drop the key): both mean empty.
/// Any other non-list value is still a contract error.
List<Object?> _optionalList(Map<String, dynamic> json, String key) {
  final v = json[key];
  if (v == null) return const [];
  if (v is List) return v;
  throw AcademyParseException('"$key" is not a list');
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

  Map<String, dynamic> toJson() => {'ar': ar, 'en': en};

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

  Map<String, dynamic> toJson() => {
    'key': key,
    'study_type': studyType,
    'title': title.toJson(),
    'position': position,
  };
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

  Map<String, dynamic> toJson() => {
    'key': key,
    'title': title.toJson(),
    'levels': [for (final l in levels) l.toJson()],
  };
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

  Map<String, dynamic> toJson() => {
    'levels': [for (final l in levels) l.toJson()],
    'study_types': [for (final t in studyTypes) t.toJson()],
  };
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

  Map<String, dynamic> toJson() => {
    'videos': videos,
    'books': books,
    'notes': notes,
  };
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

  /// Serializes the list shape the server sends (used for the offline cache;
  /// entitlements ride along as `owned` + `access_expires_at`).
  Map<String, dynamic> toJson() => {
    'id': id,
    'level_key': levelKey,
    'term': term,
    'title': title.toJson(),
    'description': description.toJson(),
    'owned': owned,
    'counts': counts.toJson(),
    if (price != null) 'price': price,
    if (currency != null) 'currency': currency,
    'access_expires_at':
        accessExpiresAt?.toUtc().toIso8601String() ?? '0001-01-01T00:00:00Z',
  };
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

/// `VideoMetadataDTO`. The subject detail never carries a YouTube id: each
/// video only says whether this student may play it ([playable]). The id is
/// obtained per play from `POST /academy/videos/{id}/play` ([VideoPlayback]).
class AcademyVideo {
  const AcademyVideo({
    required this.id,
    required this.position,
    required this.title,
    required this.description,
    this.playable = false,
  });

  final String id;
  final int position;
  final LocalizedText title;
  final LocalizedText description;

  /// True only when the server says the student may play this video. A missing
  /// flag is false: nothing unlocks by default.
  final bool playable;

  factory AcademyVideo.fromJson(Object? json) {
    final m = _map(json, 'video');
    return AcademyVideo(
      id: _requiredString(m, 'id'),
      position: _int(m, 'position'),
      title: LocalizedText.fromJson(m['title']),
      description: m['description'] == null
          ? const LocalizedText()
          : LocalizedText.fromJson(m['description']),
      playable: m['playable'] == true,
    );
  }
}

/// Answer of `POST /academy/videos/{id}/play`.
///
/// [youtubeVideoId] is sensitive: it is held only by the player screen that
/// asked for it, for the time that screen is open. It is never stored,
/// cached, logged, shown, or put in a route. [toString] redacts it so an
/// accidental log line or error message cannot leak it, and it is accepted
/// only if it has the shape of a YouTube id.
class VideoPlayback {
  const VideoPlayback({required this.videoId, required this.youtubeVideoId});

  /// The academy's own video id (not the YouTube one).
  final String videoId;
  final String youtubeVideoId;

  static final _youtubeId = RegExp(r'^[A-Za-z0-9_-]{11}$');

  factory VideoPlayback.fromJson(Map<String, dynamic> json) {
    final youtube = json['youtube_video_id'];
    if (youtube is! String || !_youtubeId.hasMatch(youtube)) {
      throw AcademyParseException('invalid playback response');
    }
    return VideoPlayback(
      videoId: _requiredString(json, 'video_id'),
      youtubeVideoId: youtube,
    );
  }

  @override
  String toString() =>
      'VideoPlayback(videoId: $videoId, youtubeVideoId: <redacted>)';
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

  /// A kind this build does not know (a later server may add one): it is
  /// listed nowhere on the subject screen (books and notes only) and labelled
  /// generically elsewhere, never with the raw server value.
  bool get isKnownKind => isBook || isNote;

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

/// `SubjectRequestDTO`: the `request` object of a not-owned subject detail.
/// The server sends it only while a request is pending
/// (`{"status": "pending"}`) and omits it otherwise.
class SubjectRequest {
  const SubjectRequest({required this.status});

  final String status;

  bool get isPending => status == 'pending';

  factory SubjectRequest.fromJson(Object? json) {
    final m = _map(json, 'request');
    return SubjectRequest(status: _requiredString(m, 'status'));
  }
}

/// Answer of `POST /academy/subjects/{id}/access-request`:
/// `AccessRequestResponseDTO`. It carries no payment data.
///
/// [supportUrl] is the `whatsapp_url` field, kept only when it is an `https`
/// URL (the backend builds `https://wa.me/<digits>` from `SUPPORT_WHATSAPP`,
/// or passes through a configured http(s) URL); anything else is dropped so a
/// malformed value can never reach the UI.
class AccessRequest {
  const AccessRequest({
    required this.id,
    required this.subjectId,
    required this.status,
    required this.createdAt,
    this.supportUrl,
  });

  final String id;
  final String subjectId;
  final String status;
  final DateTime createdAt;
  final String? supportUrl;

  bool get isPending => status == 'pending';

  factory AccessRequest.fromJson(Map<String, dynamic> json) {
    final created = DateTime.tryParse(_string(json, 'created_at'));
    if (created == null) {
      throw AcademyParseException('missing or invalid "created_at"');
    }
    final url = Uri.tryParse(_string(json, 'whatsapp_url'));
    final safeUrl = url != null && url.scheme == 'https' && url.host.isNotEmpty
        ? url.toString()
        : null;
    return AccessRequest(
      id: _requiredString(json, 'id'),
      subjectId: _requiredString(json, 'subject_id'),
      status: _requiredString(json, 'status'),
      createdAt: created.toUtc(),
      supportUrl: safeUrl,
    );
  }
}

/// `GET /academy/subjects/{id}`: `SubjectDetailDTO`.
class AcademySubjectDetail extends AcademySubject {
  // `m` is also read by the initialisers, so it cannot be a super parameter.
  // ignore: use_super_parameters
  AcademySubjectDetail.fromJson(Map<String, dynamic> m)
    : videos = _optionalList(m, 'videos').map(AcademyVideo.fromJson).toList(),
      files = _optionalList(m, 'files').map(AcademyFile.fromJson).toList(),
      request = m['request'] == null
          ? null
          : SubjectRequest.fromJson(m['request']),
      super._parse(m);

  final List<AcademyVideo> videos;
  final List<AcademyFile> files;

  /// Present only while the student has a pending access request.
  final SubjectRequest? request;

  /// A pending request on a subject the student does not own.
  bool get hasPendingRequest => !owned && (request?.isPending ?? false);

  List<AcademyFile> get books => files.where((f) => f.isBook).toList();
  List<AcademyFile> get notes => files.where((f) => f.isNote).toList();
}
