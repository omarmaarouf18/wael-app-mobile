import 'package:wael_app/core/api_client.dart';
import 'package:wael_app/models/academy_catalog.dart';
import 'package:wael_app/models/app_config.dart';
import 'package:wael_app/repositories/academy_repository.dart';

AcademyLevel level(String key, String type, int pos) => AcademyLevel(
  key: key,
  studyType: type,
  title: LocalizedText(ar: 'ar-$key', en: 'en-$key'),
  position: pos,
);

AcademySubject subject(
  String id,
  String levelKey, {
  String ar = 'مادة',
  String en = 'Subject',
  String descEn = '',
  bool owned = false,
}) => AcademySubject(
  id: id,
  levelKey: levelKey,
  term: 'first',
  title: LocalizedText(ar: ar, en: en),
  description: LocalizedText(en: descEn),
  owned: owned,
  counts: const SubjectCounts(videos: 1),
);

class FakeAcademyRepository implements AcademyRepository {
  FakeAcademyRepository({
    required this.levelList,
    this.subjectsByLevel = const {},
  });

  final List<AcademyLevel> levelList;
  Map<String, List<AcademySubject>> subjectsByLevel;
  Object? levelsError;
  Object? subjectsError;
  Object? detailError;
  int levelsCalls = 0;
  final List<(String?, int, int)> subjectCalls = [];
  int detailCalls = 0;
  bool studyTypesInResponse = true;

  /// `playVideo` answers by app video id: a [VideoPlayback] or an exception.
  final Map<String, Object> playResults = {};
  final List<String> playCalls = [];

  /// Detail responses by subject id; others get an empty detail.
  final Map<String, Map<String, dynamic>> detailJson = {};

  /// When set, `subject()` waits for it before answering.
  Future<void>? detailGate;

  /// `requestAccess` throws [accessError] when set. Otherwise it records the
  /// subject in [pendingIds], so later `subject()` answers carry
  /// `request: {"status": "pending"}` like the server's. [accessGate] holds
  /// the answer back; [accessSupportUrl] is the `whatsapp_url` it returns.
  Object? accessError;
  Future<void>? accessGate;
  String accessSupportUrl = 'https://wa.me/201000000000';
  final List<String> accessCalls = [];
  final Set<String> pendingIds = {};

  @override
  Future<AcademyLevels> levels() async {
    levelsCalls++;
    if (levelsError != null) throw levelsError!;
    // Like the real server (SPEC Section 1 decision 2, amended 2026-10-02):
    // the three study types are always there, in this order, even with no
    // levels; any other type follows.
    final byType = <String, List<AcademyLevel>>{
      'bachelor': [],
      'diploma': [],
      'vocational': [],
    };
    for (final l in levelList) {
      byType.putIfAbsent(l.studyType, () => []).add(l);
    }
    return AcademyLevels(
      levels: levelList,
      studyTypes: studyTypesInResponse
          ? [
              for (final e in byType.entries)
                AcademyStudyType(
                  key: e.key,
                  title: LocalizedText(ar: 'نوع ${e.key}', en: 'Type ${e.key}'),
                  levels: e.value,
                ),
            ]
          : const [],
    );
  }

  @override
  Future<SubjectPage> subjects({
    String? levelKey,
    String? term,
    int page = 1,
    int limit = 20,
  }) async {
    subjectCalls.add((levelKey, page, limit));
    if (subjectsError != null) throw subjectsError!;
    final all = subjectsByLevel[levelKey] ?? const [];
    final start = (page - 1) * limit;
    final items = all.skip(start).take(limit).toList();
    return SubjectPage(
      items: items,
      total: all.length,
      page: page,
      limit: limit,
    );
  }

  @override
  Future<VideoPlayback> playVideo(String videoId) async {
    playCalls.add(videoId);
    final result = playResults[videoId];
    if (result is VideoPlayback) return result;
    if (result != null) throw result;
    throw ApiException(statusCode: 404, message: 'not found');
  }

  @override
  Future<AcademySubjectDetail> subject(String id) async {
    detailCalls++;
    if (detailGate != null) await detailGate;
    if (detailError != null) throw detailError!;
    final json = Map<String, dynamic>.of(
      detailJson[id] ??
          {
            'id': id,
            'level_key': 'bachelor-y1',
            'term': 'first',
            'title': {'ar': 'مادة', 'en': 'Subject'},
            'description': {'ar': '', 'en': ''},
            'owned': false,
            'counts': {'videos': 0, 'books': 0, 'notes': 0},
            'videos': <Object>[],
            'files': <Object>[],
          },
    );
    if (pendingIds.contains(id) && json['owned'] != true) {
      json['request'] = {'status': 'pending'};
    }
    return AcademySubjectDetail.fromJson(json);
  }

  @override
  Future<AccessRequest> requestAccess(String subjectId) async {
    accessCalls.add(subjectId);
    if (accessGate != null) await accessGate;
    if (accessError != null) throw accessError!;
    pendingIds.add(subjectId);
    return AccessRequest(
      id: 'r-$subjectId',
      subjectId: subjectId,
      status: 'pending',
      createdAt: DateTime.utc(2026, 10, 2),
      supportUrl: accessSupportUrl,
    );
  }

  /// `appConfig` answers [appConfigData] (or throws [appConfigError]).
  AppConfigData appConfigData = const AppConfigData(
    supportWhatsappUrl: 'https://wa.me/201000000000',
    termsUrl: 'https://legal.elmetracademy.app/terms',
    privacyUrl: 'https://legal.elmetracademy.app/privacy',
  );
  Object? appConfigError;
  int appConfigCalls = 0;

  @override
  Future<AppConfigData> appConfig() async {
    appConfigCalls++;
    if (appConfigError != null) throw appConfigError!;
    return appConfigData;
  }
}

/// Three levels (two bachelor, one vocational) and a few subjects.
FakeAcademyRepository fake() => FakeAcademyRepository(
  levelList: [
    level('bachelor-y2', 'bachelor', 2),
    level('bachelor-y1', 'bachelor', 1),
    level('vocational', 'vocational', 5),
  ],
  subjectsByLevel: {
    'bachelor-y1': [
      subject('s1', 'bachelor-y1', en: 'Civil Law', ar: 'القانون المدني'),
      subject(
        's2',
        'bachelor-y1',
        en: 'Criminal Law',
        ar: 'القانون الجنائي',
        descEn: 'Offences',
      ),
    ],
    'bachelor-y2': [subject('s3', 'bachelor-y2', owned: true)],
    'vocational': [],
  },
);

/// JSON for `GET /academy/subjects/{id}`, with sensible defaults.
Map<String, dynamic> detailBody({
  String id = 'd1',
  bool owned = false,
  Object? price,
  String? expires,
  String term = 'first',
  String titleAr = 'القانون المدني',
  String titleEn = 'Civil Law',
  List<Map<String, dynamic>>? videos,
  List<Map<String, dynamic>>? files,
}) => {
  'id': id,
  'level_key': 'bachelor-y1',
  'term': term,
  'title': {'ar': titleAr, 'en': titleEn},
  'description': {'ar': 'وصف المادة', 'en': 'About the subject'},
  'owned': owned,
  'counts': {'videos': (videos ?? []).length, 'books': 1, 'notes': 1},
  'access_expires_at': expires ?? '0001-01-01T00:00:00Z',
  'price': ?price,
  if (price != null) 'currency': 'EGP',
  'videos': videos ?? <Map<String, dynamic>>[],
  'files': files ?? <Map<String, dynamic>>[],
};

Map<String, dynamic> videoBody(
  String id,
  int position, {
  bool playable = false,
  String en = 'Lesson',
  String ar = 'درس',
}) => {
  'id': id,
  'position': position,
  'title': {'ar': '$ar $position', 'en': '$en $position'},
  'description': {'ar': '', 'en': ''},
  'playable': playable,
};

Map<String, dynamic> fileBody(
  String id,
  String kind, {
  int size = 1048576,
  String en = 'File',
  String ar = 'ملف',
}) => {
  'id': id,
  'kind': kind,
  'title': {'ar': '$ar $id', 'en': '$en $id'},
  'size_bytes': size,
};
