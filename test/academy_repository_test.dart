import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' show MockClient;
import 'package:wael_app/core/api_client.dart';
import 'package:wael_app/models/academy_catalog.dart';
import 'package:wael_app/repositories/academy_repository.dart';

/// Records every request the repository makes and replies from [handler].
class _Fake {
  _Fake(this.handler);

  final http.Response Function(http.Request) handler;
  final List<http.Request> requests = [];
  int refreshCalls = 0;
  int logoutCalls = 0;
  bool refreshSucceeds = true;
  String token = 'access-1';

  late final ApiClient api = ApiClient(
    baseUrl: 'https://gateway.test',
    client: MockClient((req) async {
      requests.add(req);
      return handler(req);
    }),
    accessTokenReader: () async => token,
    refreshTokens: () async {
      refreshCalls++;
      if (refreshSucceeds) token = 'access-2';
      return refreshSucceeds;
    },
    forceLogout: () async => logoutCalls++,
  );

  late final HttpAcademyRepository repo = HttpAcademyRepository(api);
}

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

const _levelsBody = {
  'levels': [
    {
      'key': 'bachelor-y1',
      'study_type': 'bachelor',
      'title': {'ar': 'الفرقة الأولى', 'en': 'Year 1'},
      'position': 1,
    },
    {
      'key': 'vocational',
      'study_type': 'vocational',
      'title': {'ar': 'التدريب المهني والعملي', 'en': 'Vocational Training'},
      'position': 5,
    },
  ],
  'study_types': [
    {
      'key': 'bachelor',
      'title': {'ar': 'ليسانس الحقوق', 'en': 'LL.B. (Bachelor)'},
      'levels': [
        {
          'key': 'bachelor-y1',
          'study_type': 'bachelor',
          'title': {'ar': 'الفرقة الأولى', 'en': 'Year 1'},
          'position': 1,
        },
      ],
    },
    {
      'key': 'vocational',
      'title': {'ar': 'التدريب المهني والعملي', 'en': 'Vocational Training'},
      'levels': [
        {
          'key': 'vocational',
          'study_type': 'vocational',
          'title': {
            'ar': 'التدريب المهني والعملي',
            'en': 'Vocational Training',
          },
          'position': 5,
        },
      ],
    },
  ],
};

Map<String, dynamic> _subject({
  String id = 's1',
  Object? price,
  String? currency,
  String expires = '0001-01-01T00:00:00Z',
  String term = 'first',
}) => {
  'id': id,
  'level_key': 'bachelor-y1',
  'term': term,
  'title': {'ar': 'القانون المدني', 'en': 'Civil Law'},
  'description': {'ar': 'وصف', 'en': 'Description'},
  'owned': false,
  'counts': {'videos': 2, 'books': 1, 'notes': 3},
  'access_expires_at': expires,
  'price': ?price,
  'currency': ?currency,
};

void main() {
  group('LocalizedText.resolve', () {
    test('prefers the active language', () {
      const t = LocalizedText(ar: 'عربي', en: 'English');
      expect(t.resolve(true), 'عربي');
      expect(t.resolve(false), 'English');
    });

    test('falls back to the other language when empty', () {
      expect(const LocalizedText(ar: 'عربي').resolve(false), 'عربي');
      expect(const LocalizedText(en: 'English').resolve(true), 'English');
    });
  });

  group('levels', () {
    test('parses levels and study types from /api/v1/academy/levels', () async {
      final fake = _Fake((_) => _json(_levelsBody));
      final levels = await fake.repo.levels();

      expect(
        fake.requests.single.url.toString(),
        'https://gateway.test/api/v1/academy/levels',
      );
      expect(fake.requests.single.headers['Authorization'], 'Bearer access-1');
      expect(levels.levels.map((l) => l.key), ['bachelor-y1', 'vocational']);
      expect(levels.levels.first.studyType, 'bachelor');
      expect(levels.levels.first.position, 1);
      expect(levels.levels.first.title.resolve(true), 'الفرقة الأولى');
      expect(levels.studyTypes.map((s) => s.key), ['bachelor', 'vocational']);
      expect(levels.studyTypes.first.levels.single.key, 'bachelor-y1');
      expect(levels.studyTypes.first.title.resolve(false), 'LL.B. (Bachelor)');
    });

    test('study_types is optional', () async {
      final fake = _Fake((_) => _json({'levels': <Object>[]}));
      final levels = await fake.repo.levels();
      expect(levels.levels, isEmpty);
      expect(levels.studyTypes, isEmpty);
    });

    test('a level without a key is a parse error', () async {
      final fake = _Fake(
        (_) => _json({
          'levels': [
            {'study_type': 'bachelor', 'title': {}, 'position': 1},
          ],
        }),
      );
      expect(fake.repo.levels(), throwsA(isA<AcademyParseException>()));
    });
  });

  group('subjects', () {
    test('builds the query string and parses the page', () async {
      final fake = _Fake(
        (_) => _json({
          'items': [_subject(price: 1800, currency: 'EGP')],
          'total': 1,
          'page': 1,
          'limit': 100,
        }),
      );
      final page = await fake.repo.subjects(
        levelKey: 'bachelor-y1',
        term: 'first',
        limit: 100,
      );

      final url = fake.requests.single.url;
      expect(url.path, '/api/v1/academy/subjects');
      expect(url.queryParameters, {
        'level': 'bachelor-y1',
        'term': 'first',
        'page': '1',
        'limit': '100',
      });
      expect(page.total, 1);
      expect(page.hasMore, isFalse);
      final s = page.items.single;
      expect(s.id, 's1');
      expect(s.levelKey, 'bachelor-y1');
      expect(s.term, 'first');
      expect(s.title.resolve(true), 'القانون المدني');
      expect(s.description.resolve(false), 'Description');
      expect(s.owned, isFalse);
      expect(s.counts.videos, 2);
      expect(s.counts.books, 1);
      expect(s.counts.notes, 3);
      expect(s.counts.total, 6);
      expect(s.price, 1800);
      expect(s.currency, 'EGP');
    });

    test('omits empty filters from the query', () async {
      final fake = _Fake(
        (_) => _json({'items': <Object>[], 'total': 0, 'page': 1, 'limit': 20}),
      );
      await fake.repo.subjects(levelKey: '', term: null);
      expect(fake.requests.single.url.queryParameters, {
        'page': '1',
        'limit': '20',
      });
    });

    test('price and currency may be absent (decision D3)', () async {
      final fake = _Fake(
        (_) => _json({
          'items': [_subject()],
          'total': 1,
          'page': 1,
          'limit': 20,
        }),
      );
      final s = (await fake.repo.subjects()).items.single;
      expect(s.price, isNull);
      expect(s.currency, isNull);
    });

    test(
      'an unset Go time is no expiry; a real time is parsed as UTC',
      () async {
        final fake = _Fake(
          (_) => _json({
            'items': [
              _subject(id: 'a'),
              _subject(id: 'b', expires: '2026-12-31T21:59:59+02:00'),
            ],
            'total': 2,
            'page': 1,
            'limit': 20,
          }),
        );
        final items = (await fake.repo.subjects()).items;
        expect(items[0].accessExpiresAt, isNull);
        expect(
          items[1].accessExpiresAt,
          DateTime.utc(2026, 12, 31, 19, 59, 59),
        );
        expect(items[1].accessExpiresAt!.isUtc, isTrue);
      },
    );

    test('term may be empty (vocational)', () async {
      final fake = _Fake(
        (_) => _json({
          'items': [_subject(term: '')],
          'total': 1,
          'page': 1,
          'limit': 20,
        }),
      );
      final s = (await fake.repo.subjects()).items.single;
      expect(s.term, '');
      expect(s.hasTerm, isFalse);
    });

    test('hasMore reflects total versus page and limit', () async {
      final fake = _Fake(
        (_) => _json({
          'items': [_subject()],
          'total': 45,
          'page': 2,
          'limit': 20,
        }),
      );
      final page = await fake.repo.subjects(page: 2);
      expect(page.hasMore, isTrue);
      expect(fake.requests.single.url.queryParameters['page'], '2');
    });

    test('a missing owned flag never unlocks a subject', () async {
      final raw = _subject()..remove('owned');
      final fake = _Fake(
        (_) => _json({
          'items': [raw],
          'total': 1,
          'page': 1,
          'limit': 20,
        }),
      );
      expect((await fake.repo.subjects()).items.single.owned, isFalse);
    });

    test('items that are not a list are a parse error', () async {
      final fake = _Fake((_) => _json({'total': 0, 'page': 1, 'limit': 20}));
      expect(fake.repo.subjects(), throwsA(isA<AcademyParseException>()));
    });
  });

  group('subject detail', () {
    Map<String, dynamic> detail({Object? videoId}) => {
      ..._subject(),
      'videos': [
        {
          'id': 'v1',
          'position': 1,
          'title': {'ar': 'الدرس الأول', 'en': 'Lesson 1'},
          'description': {'ar': '', 'en': ''},
          'youtube_video_id': ?videoId,
        },
      ],
      'files': [
        {
          'id': 'f1',
          'kind': 'book',
          'title': {'ar': 'كتاب', 'en': 'Book'},
          'size_bytes': 1048576,
        },
        {
          'id': 'f2',
          'kind': 'note',
          'title': {'ar': 'مذكرة', 'en': 'Note'},
          'size_bytes': 2048,
        },
      ],
    };

    test('parses videos without a video id and files by kind', () async {
      final fake = _Fake((_) => _json(detail()));
      final d = await fake.repo.subject('s1');

      expect(fake.requests.single.url.path, '/api/v1/academy/subjects/s1');
      expect(d.id, 's1');
      expect(d.videos.single.title.resolve(false), 'Lesson 1');
      expect(d.videos.single.position, 1);
      expect(d.videos.single.youtubeVideoId, isNull);
      expect(d.videos.single.hasVideoId, isFalse);
      expect(d.books.single.id, 'f1');
      expect(d.books.single.sizeBytes, 1048576);
      expect(d.notes.single.id, 'f2');
      expect(d.files, hasLength(2));
      expect(d.owned, isFalse);
      expect(d.price, isNull);
    });

    test('keeps a well-formed server-provided video id', () async {
      final fake = _Fake((_) => _json(detail(videoId: 'dQw4w9WgXcQ')));
      final v = (await fake.repo.subject('s1')).videos.single;
      expect(v.youtubeVideoId, 'dQw4w9WgXcQ');
      expect(v.hasVideoId, isTrue);
    });

    test('drops a video id that does not look like a YouTube id', () async {
      for (final bad in [
        '',
        'short',
        'has spaces!!',
        'a' * 12,
        42,
        '../etc/pw',
      ]) {
        final fake = _Fake((_) => _json(detail(videoId: bad)));
        final v = (await fake.repo.subject('s1')).videos.single;
        expect(v.youtubeVideoId, isNull, reason: '$bad');
      }
    });

    test('the id is URL-encoded in the path', () async {
      final fake = _Fake((_) => _json(detail()));
      await fake.repo.subject('a b/c');
      expect(
        fake.requests.single.url.path,
        '/api/v1/academy/subjects/a%20b%2Fc',
      );
    });

    test('404 surfaces as ApiException without touching the session', () async {
      final fake = _Fake(
        (_) => _json({'error': 'subject not found', 'code': 'not_found'}, 404),
      );
      await expectLater(
        fake.repo.subject('nope'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 404)),
      );
      expect(fake.logoutCalls, 0);
      expect(fake.refreshCalls, 0);
    });

    test('videos that are not a list are a parse error', () async {
      final raw = detail()..['videos'] = 'nope';
      final fake = _Fake((_) => _json(raw));
      expect(fake.repo.subject('s1'), throwsA(isA<AcademyParseException>()));
    });
  });

  group('session behaviour', () {
    test('401 refreshes once and retries with the new token', () async {
      var calls = 0;
      final fake = _Fake((req) {
        calls++;
        if (req.headers['Authorization'] == 'Bearer access-1') {
          return _json({'error': 'unauthorized'}, 401);
        }
        return _json(_levelsBody);
      });
      final levels = await fake.repo.levels();
      expect(levels.levels, hasLength(2));
      expect(calls, 2);
      expect(fake.refreshCalls, 1);
      expect(fake.logoutCalls, 0);
      expect(fake.requests.last.headers['Authorization'], 'Bearer access-2');
    });

    test('401 with a failed refresh logs out and throws', () async {
      final fake = _Fake((_) => _json({'error': 'unauthorized'}, 401))
        ..refreshSucceeds = false;
      await expectLater(
        fake.repo.levels(),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)),
      );
      expect(fake.refreshCalls, 1);
      expect(fake.logoutCalls, 1);
    });

    test('5xx keeps the session: no refresh, no logout', () async {
      final fake = _Fake(
        (_) => _json({'error': 'service temporarily unavailable'}, 503),
      );
      await expectLater(
        fake.repo.subjects(levelKey: 'bachelor-y1'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 503)),
      );
      expect(fake.refreshCalls, 0);
      expect(fake.logoutCalls, 0);
    });
  });
}
