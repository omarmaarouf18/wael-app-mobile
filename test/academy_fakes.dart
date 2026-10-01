import 'package:wael_app/models/academy_catalog.dart';
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

  @override
  Future<AcademyLevels> levels() async {
    levelsCalls++;
    if (levelsError != null) throw levelsError!;
    final byType = <String, List<AcademyLevel>>{};
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
  Future<AcademySubjectDetail> subject(String id) async {
    detailCalls++;
    if (detailError != null) throw detailError!;
    return AcademySubjectDetail.fromJson({
      'id': id,
      'level_key': 'bachelor-y1',
      'term': 'first',
      'title': {'ar': 'مادة', 'en': 'Subject'},
      'description': {'ar': '', 'en': ''},
      'owned': false,
      'counts': {'videos': 0, 'books': 0, 'notes': 0},
      'videos': <Object>[],
      'files': <Object>[],
    });
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
