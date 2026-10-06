import 'dart:async' show Completer;
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

/// Marks "leave the key out" in `detail()` helpers.
const Object _absent = Object();

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

  group('levels: always-visible axes', () {
    test('parses three study types, a diploma one with no levels', () async {
      const body = {
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
            'title': {
              'ar': 'التدريب المهني والعملي',
              'en': 'Vocational Training',
            },
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
            'key': 'diploma',
            'title': {
              'ar': 'دبلومات الدراسات العليا',
              'en': 'Postgraduate Diplomas',
            },
            'levels': <Object>[],
          },
          {
            'key': 'vocational',
            'title': {
              'ar': 'التدريب المهني والعملي',
              'en': 'Vocational Training',
            },
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
      final levels = await _Fake((_) => _json(body)).repo.levels();
      expect(levels.studyTypes.map((t) => t.key), [
        'bachelor',
        'diploma',
        'vocational',
      ]);
      expect(levels.studyTypes[1].levels, isEmpty);
      expect(levels.levels.map((l) => l.key), ['bachelor-y1', 'vocational']);
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
    Map<String, dynamic> detail({Object? playable}) => {
      ..._subject(),
      'videos': [
        {
          'id': 'v1',
          'position': 1,
          'title': {'ar': 'الدرس الأول', 'en': 'Lesson 1'},
          'description': {'ar': '', 'en': ''},
          'playable': ?playable,
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

    test(
      'parses videos (no YouTube id, not playable by default) and files by kind',
      () async {
        final fake = _Fake((_) => _json(detail()));
        final d = await fake.repo.subject('s1');

        expect(fake.requests.single.url.path, '/api/v1/academy/subjects/s1');
        expect(d.id, 's1');
        expect(d.videos.single.title.resolve(false), 'Lesson 1');
        expect(d.videos.single.position, 1);
        expect(d.videos.single.playable, isFalse);
        expect(d.books.single.id, 'f1');
        expect(d.books.single.sizeBytes, 1048576);
        expect(d.notes.single.id, 'f2');
        expect(d.files, hasLength(2));
        expect(d.owned, isFalse);
        expect(d.price, isNull);
      },
    );

    test('playable is true only when the server says true', () async {
      for (final (value, expected) in [
        (true, true),
        (false, false),
        ('true', false),
        (1, false),
        (null, false),
      ]) {
        final fake = _Fake((_) => _json(detail(playable: value)));
        final v = (await fake.repo.subject('s1')).videos.single;
        expect(v.playable, expected, reason: '$value');
      }
    });

    test('a youtube_video_id in the detail is ignored', () async {
      final raw = detail(playable: true);
      (raw['videos'] as List).first['youtube_video_id'] = 'dQw4w9WgXcQ';
      final fake = _Fake((_) => _json(raw));
      final v = (await fake.repo.subject('s1')).videos.single;
      expect(v.playable, isTrue);
      expect(v.toString(), isNot(contains('dQw4w9WgXcQ')));
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

  group('subject detail request', () {
    Map<String, dynamic> detail([Object? request = _absent]) => {
      ..._subject(),
      'videos': <Object>[],
      'files': <Object>[],
      if (!identical(request, _absent)) 'request': request,
    };

    test('absent: no request and nothing pending', () {
      final d = AcademySubjectDetail.fromJson(detail());
      expect(d.request, isNull);
      expect(d.hasPendingRequest, isFalse);
    });

    test('null is the same as absent', () {
      final d = AcademySubjectDetail.fromJson(detail(null));
      expect(d.request, isNull);
      expect(d.hasPendingRequest, isFalse);
    });

    test('{"status": "pending"} parses as a pending request', () {
      final d = AcademySubjectDetail.fromJson(detail({'status': 'pending'}));
      expect(d.request!.status, 'pending');
      expect(d.request!.isPending, isTrue);
      expect(d.hasPendingRequest, isTrue);
    });

    test('another status is kept but is not pending', () {
      final d = AcademySubjectDetail.fromJson(detail({'status': 'rejected'}));
      expect(d.request!.status, 'rejected');
      expect(d.hasPendingRequest, isFalse);
    });

    test('an owned subject never counts as pending', () {
      final d = AcademySubjectDetail.fromJson({
        ...detail({'status': 'pending'}),
        'owned': true,
      });
      expect(d.hasPendingRequest, isFalse);
    });

    test('a malformed request object is a contract error', () {
      for (final bad in <Object>[
        'pending',
        1,
        <Object>[],
        <String, Object>{},
      ]) {
        expect(
          () => AcademySubjectDetail.fromJson(detail(bad)),
          throwsA(isA<AcademyParseException>()),
          reason: '$bad',
        );
      }
    });

    test('is read from the detail response end to end', () async {
      final fake = _Fake((_) => _json(detail({'status': 'pending'})));
      final d = await fake.repo.subject('s1');
      expect(d.hasPendingRequest, isTrue);
    });
  });

  group('requestAccess', () {
    const pending = {
      'id': 'r1',
      'subject_id': 's1',
      'status': 'pending',
      'created_at': '2026-10-02T09:30:00.123456Z',
      'whatsapp_url': 'https://wa.me/201000000000',
    };

    test('POSTs to the access-request endpoint and parses a 200', () async {
      final fake = _Fake((_) => _json(pending));
      final r = await fake.repo.requestAccess('s1');

      final req = fake.requests.single;
      expect(req.method, 'POST');
      expect(
        req.url.toString(),
        'https://gateway.test/api/v1/academy/subjects/s1/access-request',
      );
      expect(req.body, isEmpty);
      expect(req.headers['Authorization'], 'Bearer access-1');
      expect(r.id, 'r1');
      expect(r.subjectId, 's1');
      expect(r.status, 'pending');
      expect(r.isPending, isTrue);
      expect(r.createdAt, DateTime.utc(2026, 10, 2, 9, 30, 0, 123, 456));
      expect(r.supportUrl, 'https://wa.me/201000000000');
    });

    test('the subject id is URL-encoded in the path', () async {
      final fake = _Fake((_) => _json(pending));
      await fake.repo.requestAccess('a b/c');
      expect(
        fake.requests.single.url.path,
        '/api/v1/academy/subjects/a%20b%2Fc/access-request',
      );
    });

    test('a repeat call returns the same pending request', () async {
      final fake = _Fake((_) => _json(pending));
      final a = await fake.repo.requestAccess('s1');
      final b = await fake.repo.requestAccess('s1');
      expect(a.id, b.id);
    });

    for (final (status, body) in [
      (409, {'error': 'request conflict', 'code': 'conflict'}),
      (404, {'error': 'subject not found', 'code': 'not_found'}),
      (429, {'error': 'rate limit exceeded'}),
      (503, {'error': 'service temporarily unavailable'}),
    ]) {
      test(
        '$status surfaces as ApiException $status, session untouched',
        () async {
          final fake = _Fake((_) => _json(body, status));
          await expectLater(
            fake.repo.requestAccess('s1'),
            throwsA(
              isA<ApiException>().having((e) => e.statusCode, 'status', status),
            ),
          );
          expect(fake.requests, hasLength(1));
          expect(fake.refreshCalls, 0);
          expect(fake.logoutCalls, 0);
        },
      );
    }

    test('429 reads as rate limited', () async {
      final fake = _Fake((_) => _json({'error': 'rate limit'}, 429));
      await expectLater(
        fake.repo.requestAccess('s1'),
        throwsA(isA<ApiException>().having((e) => e.isRateLimited, 'rl', true)),
      );
    });

    test('a whatsapp_url that is not https is dropped', () async {
      for (final bad in [
        'http://wa.me/1',
        'javascript:alert(1)',
        'intent://wa.me/1',
        'wa.me/1',
        '',
        'https://',
      ]) {
        final fake = _Fake((_) => _json({...pending, 'whatsapp_url': bad}));
        final r = await fake.repo.requestAccess('s1');
        expect(r.supportUrl, isNull, reason: bad);
      }
    });

    test('a missing whatsapp_url leaves the request without a link', () async {
      final body = {...pending}..remove('whatsapp_url');
      final r = await _Fake((_) => _json(body)).repo.requestAccess('s1');
      expect(r.supportUrl, isNull);
      expect(r.isPending, isTrue);
    });

    test(
      'a response missing id, subject_id, status or created_at fails',
      () async {
        for (final key in ['id', 'subject_id', 'status', 'created_at']) {
          final body = {...pending}..remove(key);
          await expectLater(
            _Fake((_) => _json(body)).repo.requestAccess('s1'),
            throwsA(isA<AcademyParseException>()),
            reason: key,
          );
        }
        await expectLater(
          _Fake(
            (_) => _json({...pending, 'created_at': 'yesterday'}),
          ).repo.requestAccess('s1'),
          throwsA(isA<AcademyParseException>()),
        );
      },
    );
  });

  group('playVideo', () {
    const ok = {'video_id': 'v1', 'youtube_video_id': 'dQw4w9WgXcQ'};

    test('POSTs to the play endpoint and parses the answer', () async {
      final fake = _Fake((_) => _json(ok));
      final playback = await fake.repo.playVideo('v1');

      final req = fake.requests.single;
      expect(req.method, 'POST');
      expect(req.url.path, '/api/v1/academy/videos/v1/play');
      expect(req.body, isEmpty);
      expect(req.headers['Authorization'], 'Bearer access-1');
      expect(playback.videoId, 'v1');
      expect(playback.youtubeVideoId, 'dQw4w9WgXcQ');
    });

    test('the video id is URL-encoded in the path', () async {
      final fake = _Fake((_) => _json(ok));
      await fake.repo.playVideo('a b/c');
      expect(
        fake.requests.single.url.path,
        '/api/v1/academy/videos/a%20b%2Fc/play',
      );
    });

    test(
      'a generic 404 surfaces as ApiException 404, session untouched',
      () async {
        final fake = _Fake((_) => _json({'error': 'not found'}, 404));
        await expectLater(
          fake.repo.playVideo('v1'),
          throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'status', 404),
          ),
        );
        expect(fake.refreshCalls, 0);
        expect(fake.logoutCalls, 0);
      },
    );

    test('a malformed YouTube id is rejected', () async {
      for (final bad in [
        '',
        'short',
        'has spaces!!',
        'a' * 12,
        42,
        null,
        '../etc/pw',
      ]) {
        final fake = _Fake(
          (_) => _json({'video_id': 'v1', 'youtube_video_id': bad}),
        );
        await expectLater(
          fake.repo.playVideo('v1'),
          throwsA(isA<AcademyParseException>()),
          reason: '$bad',
        );
      }
    });

    test('a missing video_id is rejected', () async {
      final fake = _Fake((_) => _json({'youtube_video_id': 'dQw4w9WgXcQ'}));
      expect(fake.repo.playVideo('v1'), throwsA(isA<AcademyParseException>()));
    });

    test('toString and error messages never contain the YouTube id', () async {
      final fake = _Fake((_) => _json(ok));
      final playback = await fake.repo.playVideo('v1');
      expect(playback.toString(), isNot(contains('dQw4w9WgXcQ')));
      expect('$playback', contains('<redacted>'));
      final bad = _Fake(
        (_) => _json({'video_id': 'v1', 'youtube_video_id': 'dQw4w9WgXcQ-bad'}),
      );
      try {
        await bad.repo.playVideo('v1');
        fail('should throw');
      } on AcademyParseException catch (e) {
        expect(e.toString(), isNot(contains('dQw4w9WgXcQ')));
      }
    });

    test('401 refreshes once and retries the POST', () async {
      final fake = _Fake((req) {
        if (req.headers['Authorization'] == 'Bearer access-1') {
          return _json({'error': 'unauthorized'}, 401);
        }
        return _json(ok);
      });
      final playback = await fake.repo.playVideo('v1');
      expect(playback.youtubeVideoId, 'dQw4w9WgXcQ');
      expect(fake.refreshCalls, 1);
      expect(fake.requests.map((r) => r.method), ['POST', 'POST']);
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

  group('appConfig', () {
    const body = {
      'support_whatsapp_url': 'https://wa.me/201000000000',
      'terms_url': 'https://legal.elmetracademy.app/terms',
      'privacy_url': 'https://legal.elmetracademy.app/privacy',
      'min_version': '1.2.0',
      'latest_version': '1.4.0',
      'update_url': 'https://example.com/app',
    };

    test('parses the public config', () async {
      final config = await _Fake((_) => _json(body)).repo.appConfig();
      expect(config.supportWhatsappUrl, 'https://wa.me/201000000000');
      expect(config.termsUrl, 'https://legal.elmetracademy.app/terms');
      expect(config.privacyUrl, 'https://legal.elmetracademy.app/privacy');
      expect(config.minVersion, '1.2.0');
      expect(config.latestVersion, '1.4.0');
      expect(config.updateUrl, 'https://example.com/app');
    });

    test('500 surfaces without refresh or logout', () async {
      final fake = _Fake(
        (_) => _json({'error': 'service temporarily unavailable'}, 500),
      );
      await expectLater(
        fake.repo.appConfig(),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 500)),
      );
      expect(fake.refreshCalls, 0);
      expect(fake.logoutCalls, 0);
    });

    test('a hanging call fails as ApiException(-1, timeout)', () async {
      final api = ApiClient(
        baseUrl: 'https://gateway.test',
        client: MockClient((_) => Completer<http.Response>().future),
        timeout: const Duration(milliseconds: 100),
      );
      final repo = HttpAcademyRepository(api);
      try {
        await repo.appConfig();
        fail('expected ApiException');
      } on ApiException catch (e) {
        expect(e.statusCode, -1);
        expect(e.code, 'timeout');
      }
    });

    test('malformed JSON answers empty config, never throws', () async {
      final fake = _Fake((_) => http.Response('not json{{{', 200));
      // The client decodes leniently; the model drops what it cannot read.
      final config = await fake.repo.appConfig();
      expect(config.termsUrl, isEmpty);
    });

    test('non-https URLs are dropped', () async {
      final config = await _Fake(
        (_) => _json({
          'support_whatsapp_url': 'http://wa.me/201000000000',
          'terms_url': 'ftp://example.com/terms',
          'privacy_url': 'https://legal.elmetracademy.app/privacy',
        }),
      ).repo.appConfig();
      expect(config.supportWhatsappUrl, isEmpty);
      expect(config.termsUrl, isEmpty);
      expect(config.privacyUrl, 'https://legal.elmetracademy.app/privacy');
    });
  });
}
